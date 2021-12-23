SecureHeaders::Configuration.default do |config| # rubocop:disable Metrics/BlockLength
  config.hsts = "max-age=#{365.days.to_i}; includeSubDomains; preload"
  config.x_frame_options = 'DENY'
  config.x_content_type_options = 'nosniff'
  config.x_xss_protection = '1; mode=block'
  config.x_download_options = 'noopen'
  config.x_permitted_cross_domain_policies = 'none'

  connect_src = ["'self'", '*.nr-data.net', '*.google-analytics.com', 'us.acas.acuant.net']
  connect_src << %w[ws://localhost:3035 http://localhost:3035] if Rails.env.development?
  default_csp_config = {
    default_src: ["'self'"],
    child_src: ["'self'"], # CSP 2.0 only; replaces frame_src
    form_action: ["'self'"],
    block_all_mixed_content: true, # CSP 2.0 only;
    connect_src: connect_src.flatten,
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
  }

  if IdentityConfig.store.rails_mailer_previews_enabled
    # CSP 2.0 only; overriden by x_frame_options in some browsers
    default_csp_config[:frame_ancestors] = %w['self']
  end

  config.csp = if !Rails.env.production?
                 default_csp_config.merge(
                   script_src: ["'self'", "'unsafe-eval'", "'unsafe-inline'", 'localhost:3035'],
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

# A tiny middleware that calls a block on each request. When both:
# 1) the block returns true
# 2) the response is a 2XX response
# It deletes the Content-Security-Policy header. This is intended so that we can override
# SecureHeaders behavior and not set the headers on asset files, because the headers should be set
# on the document that links to the assets, not the assets themselves.
class SecureHeaders::RemoveContentSecurityPolicy
  # @yieldparam [Rack::Request] request
  def initialize(app, &block)
    @app = app
    @block = block
  end

  def call(env)
    status, headers, body = @app.call(env)

    if (200...300).cover?(status) && @block.call(Rack::Request.new(env))
      headers.delete('Content-Security-Policy')
    end

    [status, headers, body]
  end
end

# We need this to be called after the SecureHeaders::Railtie adds its own middleware at the top
Rails.application.configure do |config|
  config.middleware.insert_before(
    SecureHeaders::Middleware,
    SecureHeaders::RemoveContentSecurityPolicy,
  ) do |request|
    request.path.start_with?('/acuant/')
  end
end
