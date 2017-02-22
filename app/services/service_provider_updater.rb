class ServiceProviderUpdater
  PROTECTED_ATTRIBUTES = [
    :id,
    :created_at,
    :updated_at,
    :native,
  ].to_set.freeze

  def run
    dashboard_service_providers.each do |service_provider|
      update_local_caches(HashWithIndifferentAccess.new(service_provider))
    end
  end

  private

  def update_local_caches(service_provider)
    issuer = service_provider['issuer']
    update_cache(issuer, service_provider)
  end

  def update_cache(issuer, service_provider)
    if service_provider['active'] == true
      create_or_update_service_provider(issuer, service_provider)
    else
      ServiceProvider.destroy_all(issuer: issuer, native: false)
    end
  end

  def create_or_update_service_provider(issuer, service_provider)
    sp = ServiceProvider.from_issuer(issuer)
    return if sp.native?
    sync_model(sp, cleaned_service_provider(service_provider))
  end

  def sync_model(sp, cleaned_attributes)
    if sp.is_a?(NullServiceProvider)
      ServiceProvider.create(cleaned_attributes)
    else
      sp.attributes = cleaned_attributes
      sp.save!
    end
  end

  def cleaned_service_provider(service_provider)
    service_provider.except(*PROTECTED_ATTRIBUTES)
  end

  def url
    Figaro.env.dashboard_url
  end

  def dashboard_service_providers
    body = dashboard_response.body
    return parse_service_providers(body) if dashboard_response.code == 200
    log_error "Failed to parse response from #{url}: #{body}"
    []
  rescue
    log_error "Failed to contact #{url}"
    []
  end

  def parse_service_providers(body)
    JSON.parse(body)
  end

  def dashboard_response
    @_dashboard_response ||= HTTParty.get(url)
  end

  def log_error(msg)
    Rails.logger.error msg
  end
end
