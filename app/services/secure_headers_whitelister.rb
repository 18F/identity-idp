class SecureHeadersWhitelister
  def self.extract_domain(url)
    url.split('//')[1].split('/')[0]
  end

  def self.whitelisted_domains
    domains(acs_urls(ServiceProvider.active))
  end

  private

  def self.acs_urls(provider_attributes)
    provider_attributes.map { |hash| hash['acs_url'] }.compact
  end

  def self.domains(acs_urls)
    acs_urls.grep(%r{://}).map { |url| extract_domain(url) }.uniq
  end
end
