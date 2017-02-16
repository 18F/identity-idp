class OpenidConnectAuthorizeDecorator
  attr_reader :scopes, :service_provider

  delegate :metadata, to: :service_provider

  def initialize(scopes:, service_provider:)
    @scopes = scopes
    @service_provider = service_provider
  end

  def name
    metadata[:friendly_name] || metadata[:agency]
  end

  def requested_attributes
    OpenidConnectAttributeScoper.new(scopes).requested_attributes
  end

  def logo
    metadata[:logo]
  end
end
