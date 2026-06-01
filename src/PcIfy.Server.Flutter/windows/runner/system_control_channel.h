#pragma once
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <memory>

void RegisterSystemControlChannel(flutter::FlutterEngine* engine);
