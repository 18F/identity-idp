# Update ServiceProvider table by pulling from the Dashboard app API (lower environments only)
class ServiceProviderUpdater
  SP_PROTECTED_ATTRIBUTES = %i[
    created_at
    id
    updated_at
  ].to_set.freeze

  SP_IGNORED_ATTRIBUTES = %i[
    cert
  ]

  def run(service_provider = nil)
    if service_provider.present?
      update_local_caches(ActiveSupport::HashWithIndifferentAccess.new(service_provider))
    else
      dashboard_service_providers.each do |dashboard_service_provider|
        update_local_caches(
          ActiveSupport::HashWithIndifferentAccess.new(dashboard_service_provider),
        )
      end
    end
  end

  private

  def update_local_caches(service_provider)
    update_cache(service_provider)
  end

  def update_cache(service_provider)
    issuer = service_provider['issuer']
    if service_provider['active'] == true
      create_or_update_service_provider(issuer, service_provider)
    else
      ServiceProvider.where(issuer:).destroy_all
    end
  end

  def create_or_update_service_provider(issuer, service_provider)
    sp = ServiceProvider.find_by(issuer:)
    sync_model(sp, cleaned_service_provider(service_provider))
  end

  def sync_model(sp, cleaned_attributes)
    if sp
      sp.update(cleaned_attributes)
    else
      ServiceProvider.create!(cleaned_attributes)
    end
  end

  def cleaned_service_provider(service_provider)
    service_provider.except(*SP_PROTECTED_ATTRIBUTES, *SP_IGNORED_ATTRIBUTES)
  end

  def url
    IdentityConfig.store.dashboard_url
  end

  def dashboard_service_providers
    body = dashboard_response.body
    return parse_service_providers(body) if dashboard_response.status == 200
    log_error "Failed to parse response from #{url}: #{body}"
    []
  rescue StandardError
    log_error "Failed to contact #{url}"
    []
  end

  def parse_service_providers(body)
    JSON.parse(body)
  end

  def dashboard_response
    @dashboard_response ||= Faraday.get(url)
  end

  def log_error(msg)
    Rails.logger.error msg
  end
end
