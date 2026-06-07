import Cocoa
import FlutterMacOS
import IOKit.ps

@main
class AppDelegate: FlutterAppDelegate {
    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    override func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = mainFlutterWindow?.contentViewController as! FlutterViewController
        let channel = FlutterMethodChannel(
            name: "com.pcify.pcify_server/system_control",
            binaryMessenger: controller.engine.binaryMessenger)

        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }
            switch call.method {
            case "getStatus":
                result(self.getStatus())
            case "setVolume":
                if let args = call.arguments as? [String: Any],
                   let level = args["level"] as? Int {
                    self.setVolume(level)
                }
                result(nil)
            case "setMute":
                if let args = call.arguments as? [String: Any],
                   let muted = args["muted"] as? Bool {
                    self.setMuteState(muted)
                }
                result(nil)
            case "lockScreen":
                self.lockScreen()
                result(nil)
            case "wakeScreen":
                result(nil) // macOS handles this via power management
            case "getNotifications":
                result(["available": false, "items": []])
            case "clearNotifications":
                result(nil)
            case "getClipboard":
                result(self.getClipboard())
            case "getApps":
                if let args = call.arguments as? [String: Any],
                   let apps = args["apps"] as? [[String: Any]] {
                    result(self.getApps(apps))
                } else {
                    result(["apps": [], "available": true])
                }
            case "launchApp":
                if let args = call.arguments as? [String: Any],
                   let path = args["path"] as? String {
                    self.launchApp(path)
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        super.applicationDidFinishLaunching(notification)
    }

    private func getStatus() -> [String: Any] {
        let battery = getBattery()
        let volumeInfo = getVolumeInfo()
        let cpuRam = getCpuRam()
        return [
            "battery": battery,
            "volume": volumeInfo,
            "cpu": ["usage": cpuRam.cpu, "available": true],
            "ram": ["usedMb": cpuRam.usedMb, "totalMb": cpuRam.totalMb, "available": true],
            "screen": ["locked": false, "available": false],
            "disk": getDisk(),
        ]
    }

    private func getDisk() -> [String: Any] {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: "/")
            let total = (attrs[.systemSize] as? Int) ?? 0
            let free = (attrs[.systemFreeSize] as? Int) ?? 0
            let used = total > free ? total - free : 0
            return ["usedBytes": used, "totalBytes": total, "available": total > 0]
        } catch {
            return ["usedBytes": 0, "totalBytes": 0, "available": false]
        }
    }

    private func getBattery() -> [String: Any] {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]
        guard let source = sources.first else {
            return ["level": 0, "charging": false, "available": false, "temperatureCelsius": 0, "temperatureAvailable": false]
        }
        let desc = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as! [String: Any]
        let capacity = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
        let maxCapacity = desc[kIOPSMaxCapacityKey] as? Int ?? 100
        let level = maxCapacity > 0 ? (capacity * 100 / maxCapacity) : 0
        let charging = (desc[kIOPSPowerSourceStateKey] as? String) != kIOPSBatteryPowerValue
        let tempRaw = desc["Temperature"] as? Double
        let tempCelsius = tempRaw.map { Int($0) } ?? 0
        let tempAvailable = tempRaw != nil
        return ["level": level, "charging": charging, "available": true, "temperatureCelsius": tempCelsius, "temperatureAvailable": tempAvailable]
    }

    private func getClipboard() -> [String: Any] {
        let text = NSPasteboard.general.string(forType: .string) ?? ""
        let truncated = text.count > 500 ? String(text.prefix(500)) : text
        let format: String
        if truncated.hasPrefix("http://") || truncated.hasPrefix("https://") {
            format = "url"
        } else if truncated.contains("\n") && (truncated.contains("    ") || truncated.contains("\t") ||
                  truncated.contains("{") || truncated.contains("[") || truncated.contains(";")) {
            format = "code"
        } else {
            format = "text"
        }
        return ["text": truncated, "format": format, "available": true]
    }

    private func getApps(_ apps: [[String: Any]]) -> [String: Any] {
        let runningApps = NSWorkspace.shared.runningApplications
        let runningNames = Set(runningApps.compactMap { $0.localizedName?.lowercased() }
            + runningApps.compactMap { $0.bundleIdentifier?.lowercased() })
        let infos: [[String: Any]] = apps.map { app in
            let id = app["id"] as? String ?? ""
            let name = app["name"] as? String ?? ""
            let iconKey = app["iconKey"] as? String
            let processName = (app["processName"] as? String)?.lowercased() ?? ""
            let running = !processName.isEmpty && runningNames.contains(where: { $0.contains(processName) })
            var info: [String: Any] = ["id": id, "name": name, "running": running]
            if let key = iconKey { info["iconKey"] = key }
            return info
        }
        return ["apps": infos, "available": true]
    }

    private func launchApp(_ path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)
    }

    private func getVolumeInfo() -> [String: Any] {
        let volScript = "output volume of (get volume settings)"
        let muteScript = "output muted of (get volume settings)"
        let vol = runAppleScript(volScript).flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) } ?? 50
        let muted = runAppleScript(muteScript)?.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
        return ["level": vol, "muted": muted, "available": true]
    }

    private func getCpuRam() -> (cpu: Double, usedMb: Int, totalMb: Int) {
        // RAM via sysctl
        var totalRam: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &totalRam, &size, nil, 0)

        // Used RAM: parse vm_stat
        let vmStat = runCommand("/usr/bin/vm_stat") ?? ""
        var pagesFree: UInt64 = 0
        var pagesSpeculative: UInt64 = 0
        for line in vmStat.components(separatedBy: "\n") {
            if line.contains("Pages free") {
                pagesFree = parseVmStatLine(line)
            } else if line.contains("Pages speculative") {
                pagesSpeculative = parseVmStatLine(line)
            }
        }
        let pageSize: UInt64 = 4096
        let freeBytes = (pagesFree + pagesSpeculative) * pageSize
        let usedBytes = totalRam > freeBytes ? totalRam - freeBytes : 0

        // CPU via top (quick)
        var cpu = 0.0
        if let topOut = runCommand("/usr/bin/top", args: ["-l", "2", "-n", "0", "-s", "1"]) {
            for line in topOut.components(separatedBy: "\n").reversed() {
                if line.contains("CPU usage") {
                    // "CPU usage: 12.5% user, 8.3% sys, 79.2% idle"
                    if let idleRange = line.range(of: #"(\d+\.?\d*)% idle"#, options: .regularExpression) {
                        let match = String(line[idleRange])
                        if let idle = Double(match.components(separatedBy: "%").first ?? "") {
                            cpu = 100.0 - idle
                        }
                    }
                    break
                }
            }
        }

        return (
            cpu: Double(round(cpu * 10) / 10),
            usedMb: Int(usedBytes / (1024 * 1024)),
            totalMb: Int(totalRam / (1024 * 1024))
        )
    }

    private func parseVmStatLine(_ line: String) -> UInt64 {
        let parts = line.components(separatedBy: ":")
        guard parts.count >= 2 else { return 0 }
        let numStr = parts[1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ".", with: "")
        return UInt64(numStr) ?? 0
    }

    private func setVolume(_ level: Int) {
        let clamped = max(0, min(100, level))
        runAppleScriptVoid("set volume output volume \(clamped)")
    }

    private func setMuteState(_ muted: Bool) {
        runAppleScriptVoid("set volume output muted \(muted)")
    }

    private func lockScreen() {
        // Ctrl+Cmd+Q = Lock Screen shortcut
        runAppleScriptVoid("""
            tell application "System Events"
                keystroke "q" using {control down, command down}
            end tell
        """)
    }

    @discardableResult
    private func runAppleScript(_ script: String) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        try? proc.run()
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    private func runAppleScriptVoid(_ script: String) {
        _ = runAppleScript(script)
    }

    private func runCommand(_ path: String, args: [String] = []) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        try? proc.run()
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}
