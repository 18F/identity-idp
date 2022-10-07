require 'feature_management'

# rubocop:disable Metrics/BlockLength
Rails.application.config.content_security_policy do |policy|
  connect_src = ["'self'", '*.nr-data.net']

  font_src = [:self, :data, IdentityConfig.store.asset_host.presence].compact

  image_src = [
    "'self'",
    'data:',
    'login.gov',
    IdentityConfig.store.asset_host.presence,
    IdentityConfig.store.aws_region.presence &&
      "https://s3.#{IdentityConfig.store.aws_region}.amazonaws.com",
  ].select(&:present?)

  script_src = [
    :self,
    'js-agent.newrelic.com',
    '*.nr-data.net',
    IdentityConfig.store.asset_host.presence,
  ].compact

  script_src = [:self, :unsafe_eval] if !Rails.env.production?

  style_src = [:self, IdentityConfig.store.asset_host.presence].compact

  if ENV['WEBPACK_PORT']
    connect_src << "ws://localhost:#{ENV['WEBPACK_PORT']}"
    script_src << "localhost:#{ENV['WEBPACK_PORT']}"
  end

  if !IdentityConfig.store.disable_csp_unsafe_inline
    script_src << :unsafe_inline
    style_src << :unsafe_inline
  end

  if IdentityConfig.store.rails_mailer_previews_enabled
    style_src << :unsafe_inline
    # CSP 2.0 only; overriden by x_frame_options in some browsers
    policy.frame_ancestors :self
  end

  policy.frame_ancestors :self if IdentityConfig.store.component_previews_enabled

  policy.default_src :self
  policy.child_src :self # CSP 2.0 only; replaces frame_src
  policy.form_action :self
  policy.block_all_mixed_content true # CSP 2.0 only;
  policy.connect_src(*connect_src.flatten.compact)
  policy.font_src(*font_src)
  policy.img_src(*image_src)
  policy.media_src :self
  policy.object_src :none
  policy.script_src(*script_src)
  policy.style_src(*style_src)
  policy.base_uri :self
end
# rubocop:enable Metrics/BlockLength
Rails.application.configure do
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = ['script-src']
end
