Rails.application.configure do
  config.ssl_options = {
    secure_cookies: true,
    hsts: { preload: true, expires: 1.year, subdomains: true },
  }

  config.action_dispatch.default_headers.merge!(
    'X-Frame-Options' => IdentityConfig.store.rails_mailer_previews_enabled ? 'SAMEORIGIN' : 'DENY',
    'X-XSS-Protection' => '1; mode=block',
    'X-Download-Options' => 'noopen',
  )
end
