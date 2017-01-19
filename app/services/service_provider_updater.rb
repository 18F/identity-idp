class ServiceProviderUpdater
  def run
    dashboard_service_providers.each do |service_provider|
      service_provider = HashWithIndifferentAccess.new(service_provider)
      issuer = service_provider['issuer']
      SERVICE_PROVIDERS[issuer] = service_provider

      VALID_SERVICE_PROVIDERS << issuer
    end
    SecureHeadersWhitelister.new.run
  end

  private

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
