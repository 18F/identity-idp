require_relative '../../lib/plugin_manager'
require_relative '../../app/plugins/verify_by_mail'

PluginManager.add_plugin(
  VerifyByMailPlugin.new,
)
