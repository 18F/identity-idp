# frozen_string_literal: true

Rails.application.configure do
  config.ssl_options = {
    secure_cookies: true,
    hsts: { preload: true, expires: 1.year, subdomains: true },
  }

  previews_enabled = IdentityConfig.store.rails_mailer_previews_enabled ||
                     IdentityConfig.store.component_previews_enabled

  config.action_dispatch.default_headers.merge!(
    'X-XSS-Protection' => '1; mode=block',
    'X-Download-Options' => 'noopen',
  )

  if Identity::Hostdata.env == 'dev'
    # so we can embed a special lookbook component into the dev docs
    config.action_dispatch.default_headers.merge!(
      'Content-Security-Policy' => "frame-ancestors 'self' https://developers.login.gov/",
    )
  else
    config.action_dispatch.default_headers.merge!(
      'X-Frame-Options' => previews_enabled ? 'SAMEORIGIN' : 'DENY',
    )
  end
end
