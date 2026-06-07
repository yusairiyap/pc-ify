#include "system_control_channel.h"
#include <windows.h>
#include <shellapi.h>
#include <tlhelp32.h>
#include <mmdeviceapi.h>
#include <endpointvolume.h>
#include <wbemidl.h>
#include <comdef.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>
#include <pdh.h>
#include <cwctype>
#include <memory>
#include <string>
#include <unordered_set>

#pragma comment(lib, "pdh.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "wbemuuid.lib")

// PDH query for CPU
static PDH_HQUERY cpuQuery = nullptr;
static PDH_HCOUNTER cpuCounter = nullptr;

static void InitCpu() {
    if (cpuQuery != nullptr) return;
    PdhOpenQuery(nullptr, 0, &cpuQuery);
    PdhAddEnglishCounterW(cpuQuery, L"\\Processor(_Total)\\% Processor Time", 0, &cpuCounter);
    PdhCollectQueryData(cpuQuery); // first call, data is 0
}

static double GetCpuUsage() {
    if (cpuQuery == nullptr) InitCpu();
    PdhCollectQueryData(cpuQuery);
    PDH_FMT_COUNTERVALUE val;
    PdhGetFormattedCounterValue(cpuCounter, PDH_FMT_DOUBLE, nullptr, &val);
    return val.doubleValue;
}

static std::pair<int, bool> GetBatteryTemperatureWmi() {
    // COM is already initialised (STA) by the Flutter engine on this thread.
    // Do NOT call CoInitializeEx here — doing so with COINIT_MULTITHREADED on an
    // STA thread returns RPC_E_CHANGED_MODE and leaves COM in an inconsistent state.
    IWbemLocator* pLoc = nullptr;
    HRESULT hr = CoCreateInstance(CLSID_WbemLocator, nullptr, CLSCTX_INPROC_SERVER,
                                  IID_IWbemLocator, (LPVOID*)&pLoc);
    if (FAILED(hr)) return {0, false};

    IWbemServices* pSvc = nullptr;
    hr = pLoc->ConnectServer(_bstr_t(L"ROOT\\CIMV2"), nullptr, nullptr, nullptr,
                             0, nullptr, nullptr, &pSvc);
    pLoc->Release();
    if (FAILED(hr)) return {0, false};

    CoSetProxyBlanket(pSvc, RPC_C_AUTHN_WINNT, RPC_C_AUTHZ_NONE, nullptr,
                      RPC_C_AUTHN_LEVEL_CALL, RPC_C_IMP_LEVEL_IMPERSONATE,
                      nullptr, EOAC_NONE);

    IEnumWbemClassObject* pEnum = nullptr;
    hr = pSvc->ExecQuery(_bstr_t(L"WQL"),
                         _bstr_t(L"SELECT CurrentTemperature FROM Win32_Battery"),
                         WBEM_FLAG_FORWARD_ONLY | WBEM_FLAG_RETURN_IMMEDIATELY,
                         nullptr, &pEnum);
    pSvc->Release();
    if (FAILED(hr)) return {0, false};

    IWbemClassObject* pObj = nullptr;
    ULONG ret = 0;
    int tempC = 0;
    bool found = false;
    // Use a 2-second timeout to avoid blocking the platform thread indefinitely
    // if the WMI provider is slow or unavailable (e.g. no battery on desktop).
    if (pEnum->Next(2000, 1, &pObj, &ret) == WBEM_S_NO_ERROR && ret > 0) {
        VARIANT vtProp;
        hr = pObj->Get(L"CurrentTemperature", 0, &vtProp, nullptr, nullptr);
        if (SUCCEEDED(hr) && vtProp.vt == VT_I4 && vtProp.intVal > 0) {
            // Win32_Battery.CurrentTemperature is in tenths of Kelvin
            tempC = (vtProp.intVal - 2731) / 10;
            found = true;
        }
        VariantClear(&vtProp);
        pObj->Release();
    }
    pEnum->Release();
    return {tempC, found};
}

static flutter::EncodableMap GetBattery() {
    SYSTEM_POWER_STATUS ps;
    if (!GetSystemPowerStatus(&ps) || ps.BatteryLifePercent == 255) {
        return {
            {flutter::EncodableValue("level"),                flutter::EncodableValue(0)},
            {flutter::EncodableValue("charging"),             flutter::EncodableValue(false)},
            {flutter::EncodableValue("available"),            flutter::EncodableValue(false)},
            {flutter::EncodableValue("temperatureCelsius"),   flutter::EncodableValue(0)},
            {flutter::EncodableValue("temperatureAvailable"), flutter::EncodableValue(false)},
        };
    }
    bool charging = ps.ACLineStatus == 1;
    auto [tempC, tempAvail] = GetBatteryTemperatureWmi();
    return {
        {flutter::EncodableValue("level"),                flutter::EncodableValue((int)ps.BatteryLifePercent)},
        {flutter::EncodableValue("charging"),             flutter::EncodableValue(charging)},
        {flutter::EncodableValue("available"),            flutter::EncodableValue(true)},
        {flutter::EncodableValue("temperatureCelsius"),   flutter::EncodableValue(tempC)},
        {flutter::EncodableValue("temperatureAvailable"), flutter::EncodableValue(tempAvail)},
    };
}

static flutter::EncodableMap GetRam() {
    MEMORYSTATUSEX ms;
    ms.dwLength = sizeof(ms);
    if (!GlobalMemoryStatusEx(&ms)) {
        return {
            {flutter::EncodableValue("usedMb"),    flutter::EncodableValue(0)},
            {flutter::EncodableValue("totalMb"),   flutter::EncodableValue(0)},
            {flutter::EncodableValue("available"), flutter::EncodableValue(false)},
        };
    }
    int usedMb = (int)((ms.ullTotalPhys - ms.ullAvailPhys) / (1024 * 1024));
    int totalMb = (int)(ms.ullTotalPhys / (1024 * 1024));
    return {
        {flutter::EncodableValue("usedMb"),    flutter::EncodableValue(usedMb)},
        {flutter::EncodableValue("totalMb"),   flutter::EncodableValue(totalMb)},
        {flutter::EncodableValue("available"), flutter::EncodableValue(true)},
    };
}

static flutter::EncodableMap GetDisk() {
    ULARGE_INTEGER freeBytesAvailableToCaller, totalBytes, totalFreeBytes;
    if (!GetDiskFreeSpaceExW(L"C:\\", &freeBytesAvailableToCaller, &totalBytes, &totalFreeBytes)) {
        return {
            {flutter::EncodableValue("usedBytes"),  flutter::EncodableValue((int64_t)0)},
            {flutter::EncodableValue("totalBytes"), flutter::EncodableValue((int64_t)0)},
            {flutter::EncodableValue("available"),  flutter::EncodableValue(false)},
        };
    }
    int64_t total = (int64_t)totalBytes.QuadPart;
    int64_t free_ = (int64_t)totalFreeBytes.QuadPart;
    return {
        {flutter::EncodableValue("usedBytes"),  flutter::EncodableValue(total - free_)},
        {flutter::EncodableValue("totalBytes"), flutter::EncodableValue(total)},
        {flutter::EncodableValue("available"),  flutter::EncodableValue(true)},
    };
}

static IAudioEndpointVolume* GetAudioVolume() {
    IMMDeviceEnumerator* enumerator = nullptr;
    CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
        __uuidof(IMMDeviceEnumerator), (void**)&enumerator);
    if (!enumerator) return nullptr;
    IMMDevice* device = nullptr;
    enumerator->GetDefaultAudioEndpoint(eRender, eMultimedia, &device);
    enumerator->Release();
    if (!device) return nullptr;
    IAudioEndpointVolume* vol = nullptr;
    device->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL, nullptr, (void**)&vol);
    device->Release();
    return vol;
}

static flutter::EncodableMap GetVolume() {
    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    auto* vol = GetAudioVolume();
    if (!vol) {
        return {
            {flutter::EncodableValue("level"),     flutter::EncodableValue(50)},
            {flutter::EncodableValue("muted"),     flutter::EncodableValue(false)},
            {flutter::EncodableValue("available"), flutter::EncodableValue(false)},
        };
    }
    float scalar = 0.0f;
    vol->GetMasterVolumeLevelScalar(&scalar);
    BOOL muted = FALSE;
    vol->GetMute(&muted);
    vol->Release();
    return {
        {flutter::EncodableValue("level"),     flutter::EncodableValue((int)(scalar * 100))},
        {flutter::EncodableValue("muted"),     flutter::EncodableValue((bool)muted)},
        {flutter::EncodableValue("available"), flutter::EncodableValue(true)},
    };
}

static void SetVolumeLevel(int percent) {
    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    auto* vol = GetAudioVolume();
    if (!vol) return;
    float scalar = (float)std::max(0, std::min(100, percent)) / 100.0f;
    vol->SetMasterVolumeLevelScalar(scalar, nullptr);
    vol->Release();
}

static void SetMuteState(bool muted) {
    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    auto* vol = GetAudioVolume();
    if (!vol) return;
    vol->SetMute(muted ? TRUE : FALSE, nullptr);
    vol->Release();
}

static flutter::EncodableMap GetClipboard() {
    std::string text;
    bool available = false;
    if (OpenClipboard(nullptr)) {
        HANDLE hData = GetClipboardData(CF_UNICODETEXT);
        if (hData) {
            wchar_t* pwstr = (wchar_t*)GlobalLock(hData);
            if (pwstr) {
                int len = WideCharToMultiByte(CP_UTF8, 0, pwstr, -1, nullptr, 0, nullptr, nullptr);
                if (len > 1) {
                    text.resize(len - 1);
                    WideCharToMultiByte(CP_UTF8, 0, pwstr, -1, &text[0], len, nullptr, nullptr);
                }
                GlobalUnlock(hData);
            }
        }
        CloseClipboard();
        available = true;
    }
    if (text.length() > 500) text = text.substr(0, 500);

    std::string format = "text";
    if (text.substr(0, 7) == "http://" || text.substr(0, 8) == "https://") {
        format = "url";
    } else if (text.find('\n') != std::string::npos &&
               (text.find("    ") != std::string::npos ||
                text.find('\t') != std::string::npos ||
                text.find('{') != std::string::npos ||
                text.find('[') != std::string::npos ||
                text.find(';') != std::string::npos)) {
        format = "code";
    }
    return {
        {flutter::EncodableValue("text"),      flutter::EncodableValue(text)},
        {flutter::EncodableValue("format"),    flutter::EncodableValue(format)},
        {flutter::EncodableValue("available"), flutter::EncodableValue(available)},
    };
}

// Build a set of running exe names (without extension, lowercased) from one snapshot.
static std::unordered_set<std::wstring> GetRunningProcessNames() {
    std::unordered_set<std::wstring> names;
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) return names;
    PROCESSENTRY32W pe;
    pe.dwSize = sizeof(pe);
    if (Process32FirstW(snap, &pe)) {
        do {
            std::wstring exe(pe.szExeFile);
            size_t dot = exe.rfind(L'.');
            if (dot != std::wstring::npos) exe = exe.substr(0, dot);
            // Lowercase for case-insensitive lookup
            for (auto& c : exe) c = towlower(c);
            names.insert(std::move(exe));
        } while (Process32NextW(snap, &pe));
    }
    CloseHandle(snap);
    return names;
}

static flutter::EncodableMap GetApps(const flutter::EncodableList& apps) {
    // Take a single process snapshot for all apps rather than one per app.
    const auto running = GetRunningProcessNames();

    flutter::EncodableList infos;
    for (const auto& appVal : apps) {
        const auto* app = std::get_if<flutter::EncodableMap>(&appVal);
        if (!app) continue;

        std::string id, name;
        bool isRunning = false;
        flutter::EncodableValue iconKeyVal;

        auto idIt = app->find(flutter::EncodableValue("id"));
        if (idIt != app->end()) {
            if (auto* s = std::get_if<std::string>(&idIt->second)) id = *s;
        }
        auto nameIt = app->find(flutter::EncodableValue("name"));
        if (nameIt != app->end()) {
            if (auto* s = std::get_if<std::string>(&nameIt->second)) name = *s;
        }
        auto iconIt = app->find(flutter::EncodableValue("iconKey"));
        if (iconIt != app->end()) iconKeyVal = iconIt->second;

        auto procIt = app->find(flutter::EncodableValue("processName"));
        if (procIt != app->end()) {
            if (auto* procStr = std::get_if<std::string>(&procIt->second)) {
                if (!procStr->empty()) {
                    int len = MultiByteToWideChar(CP_UTF8, 0, procStr->c_str(), -1, nullptr, 0);
                    std::wstring wname(len - 1, L'\0');
                    MultiByteToWideChar(CP_UTF8, 0, procStr->c_str(), -1, &wname[0], len);
                    for (auto& c : wname) c = towlower(c);
                    isRunning = running.count(wname) > 0;
                }
            }
        }

        flutter::EncodableMap info = {
            {flutter::EncodableValue("id"),      flutter::EncodableValue(id)},
            {flutter::EncodableValue("name"),    flutter::EncodableValue(name)},
            {flutter::EncodableValue("running"), flutter::EncodableValue(isRunning)},
        };
        if (std::holds_alternative<std::string>(iconKeyVal)) {
            info[flutter::EncodableValue("iconKey")] = iconKeyVal;
        }
        infos.push_back(flutter::EncodableValue(info));
    }
    return {
        {flutter::EncodableValue("apps"),      flutter::EncodableValue(infos)},
        {flutter::EncodableValue("available"), flutter::EncodableValue(true)},
    };
}

void RegisterSystemControlChannel(flutter::FlutterEngine* engine) {
    InitCpu();
    auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        engine->messenger(),
        "com.pcify.pcify_server/system_control",
        &flutter::StandardMethodCodec::GetInstance());

    channel->SetMethodCallHandler(
        [](const flutter::MethodCall<flutter::EncodableValue>& call,
           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

            const auto& method = call.method_name();

            if (method == "getStatus") {
                double cpu = GetCpuUsage();
                flutter::EncodableMap response = {
                    {flutter::EncodableValue("battery"), flutter::EncodableValue(GetBattery())},
                    {flutter::EncodableValue("volume"),  flutter::EncodableValue(GetVolume())},
                    {flutter::EncodableValue("cpu"), flutter::EncodableValue(flutter::EncodableMap{
                        {flutter::EncodableValue("usage"),     flutter::EncodableValue(cpu)},
                        {flutter::EncodableValue("available"), flutter::EncodableValue(true)},
                    })},
                    {flutter::EncodableValue("ram"), flutter::EncodableValue(GetRam())},
                    {flutter::EncodableValue("screen"), flutter::EncodableValue(flutter::EncodableMap{
                        {flutter::EncodableValue("locked"),    flutter::EncodableValue(false)},
                        {flutter::EncodableValue("available"), flutter::EncodableValue(false)},
                    })},
                    {flutter::EncodableValue("disk"), flutter::EncodableValue(GetDisk())},
                };
                result->Success(flutter::EncodableValue(response));
            } else if (method == "setVolume") {
                const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
                int level = 50;
                if (args) {
                    auto it = args->find(flutter::EncodableValue("level"));
                    if (it != args->end()) level = std::get<int>(it->second);
                }
                SetVolumeLevel(level);
                result->Success();
            } else if (method == "setMute") {
                const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
                bool muted = false;
                if (args) {
                    auto it = args->find(flutter::EncodableValue("muted"));
                    if (it != args->end()) muted = std::get<bool>(it->second);
                }
                SetMuteState(muted);
                result->Success();
            } else if (method == "lockScreen") {
                LockWorkStation();
                result->Success();
            } else if (method == "wakeScreen") {
                mouse_event(MOUSEEVENTF_MOVE, 0, 0, 0, 0);
                result->Success();
            } else if (method == "getClipboard") {
                result->Success(flutter::EncodableValue(GetClipboard()));
            } else if (method == "getApps") {
                const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
                flutter::EncodableList appsList;
                if (args) {
                    auto it = args->find(flutter::EncodableValue("apps"));
                    if (it != args->end()) {
                        if (auto* list = std::get_if<flutter::EncodableList>(&it->second)) {
                            appsList = *list;
                        }
                    }
                }
                result->Success(flutter::EncodableValue(GetApps(appsList)));
            } else if (method == "launchApp") {
                const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
                if (args) {
                    auto it = args->find(flutter::EncodableValue("path"));
                    if (it != args->end()) {
                        if (auto* pathStr = std::get_if<std::string>(&it->second)) {
                            int len = MultiByteToWideChar(CP_UTF8, 0, pathStr->c_str(), -1, nullptr, 0);
                            std::wstring wpath(len - 1, L'\0');
                            MultiByteToWideChar(CP_UTF8, 0, pathStr->c_str(), -1, &wpath[0], len);
                            ShellExecuteW(nullptr, L"open", wpath.c_str(), nullptr, nullptr, SW_SHOW);
                        }
                    }
                }
                result->Success();
            } else {
                result->NotImplemented();
            }
        });

    // Keep channel alive
    channel.release();
}
