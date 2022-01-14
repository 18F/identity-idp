require 'feature_management'

if FeatureManagement.rails_csp_tooling_enabled?
  Rails.application.config.content_security_policy do |policy|
    connect_src = ["'self'", '*.nr-data.net', '*.google-analytics.com', 'us.acas.acuant.net']

    font_src = [:self, :data, IdentityConfig.store.asset_host.presence].compact

    image_src = [
      "'self'",
      'data:',
      'login.gov',
      IdentityConfig.store.asset_host.presence,
      'idscangoweb.acuant.com',
      IdentityConfig.store.aws_region.presence &&
        "https://s3.#{IdentityConfig.store.aws_region}.amazonaws.com",
    ].select(&:present?)

    script_src = [
      :self,
      'js-agent.newrelic.com',
      '*.nr-data.net',
      'dap.digitalgov.gov',
      '*.google-analytics.com',
      IdentityConfig.store.asset_host.presence,
    ].compact

    style_src = [:self, IdentityConfig.store.asset_host.presence].compact

    if ENV['WEBPACK_PORT']
      connect_src << "ws://localhost:#{ENV['WEBPACK_PORT']}"
      script_src << "localhost:#{ENV['WEBPACK_PORT']}"
    end

    policy.default_src :self
    policy.child_src :self # CSP 2.0 only; replaces frame_src
    policy.form_action :self
    policy.block_all_mixed_content true # CSP 2.0 only;
    policy.connect_src *connect_src.flatten.compact
    policy.font_src *font_src
    policy.img_src *image_src
    policy.media_src :self
    policy.object_src :none
    policy.script_src *script_src
    policy.style_src *style_src
    policy.base_uri :self
  end
end
