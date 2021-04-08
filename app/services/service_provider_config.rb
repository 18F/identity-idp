class ServiceProviderConfig
  def initialize(issuer:)
    @issuer = issuer
  end

  def sp_attributes
    service_provider.metadata
  end

  def service_provider
    @_sp ||= ServiceProvider.from_issuer(issuer)
  end

  private

  attr_reader :issuer
end
