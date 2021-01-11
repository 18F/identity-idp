SecureHeaders::Configuration.default do |config| # rubocop:disable Metrics/BlockLength
  config.hsts = "max-age=#{365.days.to_i}; includeSubDomains; preload"
  config.x_frame_options = 'DENY'
  config.x_content_type_options = 'nosniff'
  config.x_xss_protection = '1; mode=block'
  config.x_download_options = 'noopen'
  config.x_permitted_cross_domain_policies = 'none'

  connect_src = ["'self'", '*.newrelic.com', '*.nr-data.net', '*.google-analytics.com',
                 'services.assureid.net']
  connect_src << %w[ws://localhost:3035 http://localhost:3035] if Rails.env.development?
  default_csp_config = {
    default_src: ["'self'"],
    child_src: ["'self'", 'www.google.com'], # CSP 2.0 only; replaces frame_src
    # frame_ancestors: %w('self'), # CSP 2.0 only; overriden by x_frame_options in some browsers
    block_all_mixed_content: true, # CSP 2.0 only;
    connect_src: connect_src.flatten,
    font_src: ["'self'", 'data:', AppConfig.env.asset_host],
    img_src: [
      "'self'",
      'data:',
      'login.gov',
      AppConfig.env.asset_host,
      'idscangoweb.acuant.com',
      AppConfig.env.aws_region && "https://s3.#{AppConfig.env.aws_region}.amazonaws.com",
    ].select(&:present?),
    media_src: ["'self'"],
    object_src: ["'none'"],
    script_src: [
      "'self'",
      '*.newrelic.com',
      '*.nr-data.net',
      'dap.digitalgov.gov',
      '*.google-analytics.com',
      'www.google.com',
      'www.gstatic.com',
      AppConfig.env.asset_host,
    ],
    style_src: ["'self'", AppConfig.env.asset_host],
    base_uri: ["'self'"],
  }

  config.csp = if !Rails.env.production?
                 default_csp_config.merge(
                   script_src: ["'self'", "'unsafe-eval'", "'unsafe-inline'"],
                   style_src: ["'self'", "'unsafe-inline'"],
                 )
               else
                 default_csp_config
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


# We need this to be called after the SecureHeaders::Railtie adds its own middleware at the top
Rails.application.configure do |config|
  require 'manual_secure_headers_override'

  acuant_sdk_static_files = %w[
    AcuantImageProcessingWorker.min.js
    AcuantImageProcessingWorker.wasm
  ].freeze

  config.middleware.insert_after 0, ManualSecureHeadersOverride do |request|
    if acuant_sdk_static_files.any? { |file| request.path.end_with?(file) }
      SecureHeaders.append_content_security_policy_directives(
        request,
        script_src: ["'unsafe-eval'"]
      )
    end
  end
end
