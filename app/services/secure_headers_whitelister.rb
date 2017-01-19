class SecureHeadersWhitelister
  def run
    whitelisted_domains = domains(acs_urls(SERVICE_PROVIDERS.values))
    SecureHeaders::Configuration.override(:saml) do |config|
      config.csp[:form_action] += whitelisted_domains
    end
  end

  private

  def acs_urls(provider_attributes)
    provider_attributes.map { |hash| hash['acs_url'] }.compact
  end

  def domains(acs_urls)
    acs_urls.map { |url| url.split('//')[1].split('/')[0] }.uniq
  end
end
