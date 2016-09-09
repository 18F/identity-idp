class ServiceProviderConfig
  def initialize(issuer:)
    @issuer = issuer
  end

  def sp_attributes
    SERVICE_PROVIDERS.fetch(issuer, {}).symbolize_keys
  end

  private

  attr_reader :issuer
end
