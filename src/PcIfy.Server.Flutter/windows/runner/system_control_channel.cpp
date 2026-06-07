#include "system_control_channel.h"
#include <windows.h>
#include <mmdeviceapi.h>
#include <endpointvolume.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>
#include <pdh.h>
#include <memory>
#include <string>

#pragma comment(lib, "pdh.lib")
#pragma comment(lib, "ole32.lib")

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

static flutter::EncodableMap GetBattery() {
    SYSTEM_POWER_STATUS ps;
    if (!GetSystemPowerStatus(&ps) || ps.BatteryLifePercent == 255) {
        return {
            {flutter::EncodableValue("level"), flutter::EncodableValue(0)},
            {flutter::EncodableValue("charging"), flutter::EncodableValue(false)},
            {flutter::EncodableValue("available"), flutter::EncodableValue(false)},
        };
    }
    bool charging = ps.ACLineStatus == 1;
    return {
        {flutter::EncodableValue("level"), flutter::EncodableValue((int)ps.BatteryLifePercent)},
        {flutter::EncodableValue("charging"), flutter::EncodableValue(charging)},
        {flutter::EncodableValue("available"), flutter::EncodableValue(true)},
    };
}

static flutter::EncodableMap GetRam() {
    MEMORYSTATUSEX ms;
    ms.dwLength = sizeof(ms);
    if (!GlobalMemoryStatusEx(&ms)) {
        return {
            {flutter::EncodableValue("usedMb"), flutter::EncodableValue(0)},
            {flutter::EncodableValue("totalMb"), flutter::EncodableValue(0)},
            {flutter::EncodableValue("available"), flutter::EncodableValue(false)},
        };
    }
    int usedMb = (int)((ms.ullTotalPhys - ms.ullAvailPhys) / (1024 * 1024));
    int totalMb = (int)(ms.ullTotalPhys / (1024 * 1024));
    return {
        {flutter::EncodableValue("usedMb"), flutter::EncodableValue(usedMb)},
        {flutter::EncodableValue("totalMb"), flutter::EncodableValue(totalMb)},
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
            {flutter::EncodableValue("level"), flutter::EncodableValue(50)},
            {flutter::EncodableValue("muted"), flutter::EncodableValue(false)},
            {flutter::EncodableValue("available"), flutter::EncodableValue(false)},
        };
    }
    float scalar = 0.0f;
    vol->GetMasterVolumeLevelScalar(&scalar);
    BOOL muted = FALSE;
    vol->GetMute(&muted);
    vol->Release();
    return {
        {flutter::EncodableValue("level"), flutter::EncodableValue((int)(scalar * 100))},
        {flutter::EncodableValue("muted"), flutter::EncodableValue((bool)muted)},
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
                        {flutter::EncodableValue("usage"), flutter::EncodableValue(cpu)},
                        {flutter::EncodableValue("available"), flutter::EncodableValue(true)},
                    })},
                    {flutter::EncodableValue("ram"), flutter::EncodableValue(GetRam())},
                    {flutter::EncodableValue("screen"), flutter::EncodableValue(flutter::EncodableMap{
                        {flutter::EncodableValue("locked"), flutter::EncodableValue(false)},
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
            } else {
                result->NotImplemented();
            }
        });

    // Keep channel alive
    channel.release();
}
