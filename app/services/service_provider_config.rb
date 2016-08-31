class ServiceProviderConfig
  def initialize(issuer:)
    @issuer = issuer
  end

  def sp_attributes
    SERVICE_PROVIDERS['valid_hosts'].fetch(issuer, {}).symbolize_keys
  end

  def self.fetch_providers_from_domain_name_or_rails_env
    if Figaro.env.domain_name == 'superb.legit.domain.gov'
      SERVICE_PROVIDERS.merge!(SERVICE_PROVIDERS.fetch('superb.legit.domain.gov', {}))
    else
      SERVICE_PROVIDERS.merge!(SERVICE_PROVIDERS.fetch(Rails.env, {}))
    end
  end

  private

  attr_reader :issuer
end
