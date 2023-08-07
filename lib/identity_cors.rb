# frozen_string_literal: true

class IdentityCors
  FEDERALIST_REGEX = %r{\Ahttps://federalist-[0-9a-f-]+(\.sites)?\.pages\.cloud\.gov\z}
  STATIC_SITE_ALLOWED_ORIGINS = [
    'https://www.login.gov',
    'https://login.gov',
    'https://handbook.login.gov',
    FEDERALIST_REGEX,
  ].freeze

  def self.allowed_origins_static_sites
    return STATIC_SITE_ALLOWED_ORIGINS unless Rails.env.development? || Rails.env.test?
    allowed_origins = STATIC_SITE_ALLOWED_ORIGINS.dup
    allowed_origins << %r{https?://localhost(:\d+)?\z}
    allowed_origins << %r{https?://127\.0\.0\.1(:\d+)?\z}

    allowed_origins
  end

  def self.allowed_redirect_uri?(source)
    return false if source == "https://#{IdentityConfig.store.domain_name}"

    redirect_uris = Rails.cache.fetch(
      'all_service_provider_redirect_uris_cors',
      expires_in: IdentityConfig.store.all_redirect_uris_cache_duration_minutes.minutes,
    ) do
      ServiceProvider.pluck(:redirect_uris).flatten.compact.map do |uri|
        protocol, domain_path = uri.split('//', 2)
        domain, _path = domain_path&.split('/', 2)
        "#{protocol}//#{domain}"
      end.uniq
    end

    redirect_uris.any? { |uri| uri == source }
  end
end
