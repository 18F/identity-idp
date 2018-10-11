class OpenidConnectAuthorizeDecorator
  def initialize(scopes:)
    @scopes = scopes
  end

  def requested_attributes
    OpenidConnectAttributeScoper.new(scopes).requested_attributes
  end

  private

  attr_reader :scopes
end
