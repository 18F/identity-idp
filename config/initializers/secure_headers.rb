require 'feature_management'

SecureHeaders::Configuration.default do |config| # rubocop:disable Metrics/BlockLength
  config.hsts = "max-age=#{365.days.to_i}; includeSubDomains; preload"
  config.x_frame_options = 'DENY'
  config.x_content_type_options = 'nosniff'
  config.x_xss_protection = '1; mode=block'
  config.x_download_options = 'noopen'
  config.x_permitted_cross_domain_policies = 'none'

  default_csp_config = {
    default_src: ["'self'"],
    child_src: ["'self'"], # CSP 2.0 only; replaces frame_src
    form_action: ["'self'"],
    block_all_mixed_content: true, # CSP 2.0 only;
    connect_src: ["'self'", '*.nr-data.net', '*.google-analytics.com', 'us.acas.acuant.net'],
    font_src: ["'self'", 'data:', IdentityConfig.store.asset_host.presence],
    img_src: [
      "'self'",
      'data:',
      'login.gov',
      IdentityConfig.store.asset_host.presence,
      'idscangoweb.acuant.com',
      IdentityConfig.store.aws_region.presence &&
        "https://s3.#{IdentityConfig.store.aws_region}.amazonaws.com",
    ].select(&:present?),
    media_src: ["'self'"],
    object_src: ["'none'"],
    script_src: [
      "'self'",
      'js-agent.newrelic.com',
      '*.nr-data.net',
      'dap.digitalgov.gov',
      '*.google-analytics.com',
      IdentityConfig.store.asset_host.presence,
    ],
    style_src: ["'self'", IdentityConfig.store.asset_host.presence],
    base_uri: ["'self'"],
    preserve_schemes: true,
    disable_nonce_backwards_compatibility: true,
  }

  if IdentityConfig.store.rails_mailer_previews_enabled
    # CSP 2.0 only; overriden by x_frame_options in some browsers
    default_csp_config[:frame_ancestors] = %w['self']
  end

  if ENV['WEBPACK_PORT']
    default_csp_config[:connect_src] << "ws://localhost:#{ENV['WEBPACK_PORT']}"
    default_csp_config[:script_src] << "localhost:#{ENV['WEBPACK_PORT']}"
  end

  if FeatureManagement.rails_csp_tooling_enabled?
    config.csp = SecureHeaders::OPT_OUT
  else
    config.csp = default_csp_config
  end

  config.cookies = {
    secure: true, # mark all cookies as "Secure"
    httponly: true, # mark all cookies as "HttpOnly"
    samesite: {
      lax: true, # SameSite setting.
    },
  }

  # Temporarily disabled until we configure pinning. See GitHub issue #1895.
  # config.hpkp = {
  #   report_only: false,
  #   max_age: 60.days.to_i,
  #   include_subdomains: true,
  #   pins: [
  #     { sha256: 'abc' },
  #     { sha256: '123' }
  #   ]
  # }
end
