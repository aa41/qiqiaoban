#include "include/qiqiaoban/qiqiaoban_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "qiqiaoban_plugin.h"

void QiqiaobanPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  qiqiaoban::QiqiaobanPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
