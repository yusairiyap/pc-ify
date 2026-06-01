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
            "screen": ["locked": false, "available": false]
        ]
    }

    private func getBattery() -> [String: Any] {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]
        guard let source = sources.first else {
            return ["level": 0, "charging": false, "available": false]
        }
        let desc = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as! [String: Any]
        let capacity = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
        let maxCapacity = desc[kIOPSMaxCapacityKey] as? Int ?? 100
        let level = maxCapacity > 0 ? (capacity * 100 / maxCapacity) : 0
        let charging = (desc[kIOPSPowerSourceStateKey] as? String) != kIOPSBatteryPowerValue
        return ["level": level, "charging": charging, "available": true]
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
