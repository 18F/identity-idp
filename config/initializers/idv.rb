require_relative '../../lib/plugin_manager'
require_relative '../../app/plugins/idv/analytics_plugin'
require_relative '../../app/plugins/idv/attempts_api_plugin'
require_relative '../../app/plugins/idv/funnel_plugin'
require_relative '../../app/plugins/idv/proofing_component_plugin'
require_relative '../../app/plugins/idv/user_events_plugin'
require_relative '../../app/plugins/idv/verify_by_mail'

PluginManager.instance.add_plugins(
  idv_analytics: AnalyticsPlugin.new,
  idv_attempts_api: AttemptsApiPlugin.new,
  idv_funnel: FunnelPlugin.new,
  idv_proofing_component: ProofingComponentPlugin.new,
  idv_user_events: UserEventsPlugin.new,
  verify_by_mail: VerifyByMailPlugin.new,
)
