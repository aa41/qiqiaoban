//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <qiqiaoban/qiqiaoban_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) qiqiaoban_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "QiqiaobanPlugin");
  qiqiaoban_plugin_register_with_registrar(qiqiaoban_registrar);
}
