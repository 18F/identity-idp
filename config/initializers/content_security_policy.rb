# frozen_string_literal: true

require 'feature_management'

# rubocop:disable Metrics/BlockLength
Rails.application.config.content_security_policy do |policy|
  connect_src = ["'self'"]

  font_src = [:self, :data, IdentityConfig.store.asset_host.presence].compact

  image_src = [
    "'self'",
    'data:',
    'login.gov',
    IdentityConfig.store.asset_host.presence,
    IdentityConfig.store.aws_region.presence &&
      "https://s3.#{IdentityConfig.store.aws_region}.amazonaws.com",
  ].select(&:present?)

  script_src = [:self, IdentityConfig.store.asset_host.presence].compact
  script_src << :unsafe_eval if !Rails.env.production?

  style_src = [:self, IdentityConfig.store.asset_host.presence].compact

  if ENV['WEBPACK_PORT']
    connect_src << "ws://localhost:#{ENV['WEBPACK_PORT']}"
    script_src << "localhost:#{ENV['WEBPACK_PORT']}"
  end

  if IdentityConfig.store.rails_mailer_previews_enabled
    style_src << :unsafe_inline
    # CSP 2.0 only; overriden by x_frame_options in some browsers
    policy.frame_ancestors :self
  end

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
  # The nonce has to stay the same for the life of a session: pages fetch fragments over XHR and
  # apply inline styles and scripts carrying the nonce the page was first served with, so a value
  # that changed on every request would be blocked by the policy. Scripts can read the nonce of any
  # element on the page through `element.nonce`, so it must not be the session identifier itself.
  # A keyed hash of the session identifier is stable for the session, differs between sessions and
  # cannot be reversed to the cookie value.
  config.content_security_policy_nonce_generator = lambda do |request|
    OpenSSL::HMAC.base64digest(
      'SHA256', Rails.application.secret_key_base, request.session.id.to_s
    )
  end
  config.content_security_policy_nonce_directives = ['script-src', 'style-src']
end
