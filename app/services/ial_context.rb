class IalContext
  # @param ial [String, Integer] IAL level as either an integer (see Identity::IAL2, etc)
  #   or a string see Saml::Idp::Constants contexts
  # @param service_provider [ServiceProvider]
  def initialize(ial:, service_provider:)
    @ial = int_ial(ial)
    @service_provider = service_provider
  end

  def ial2_service_provider?
    service_provider.ial == Identity::IAL2
  end

  def ialmax_requested?
    ial&.zero?
    # Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF == ial
  end

  def ial2_or_greater?
    ial2_requested? || ial2_strict_requested?
  end

  def ial2_requested?
    ial == Identity::IAL2 && !service_provider.liveness_checking_required
    # Saml::Idp::Constants::IAL2_AUTHN_CONTEXTS.include?(ial)
  end

  def ial2_strict_requested?
    ial == Identity::IAL2_STRICT ||
      (ial == Identity::IAL2 && service_provider.liveness_checking_required)
  end

  def ial_for_identity_record
    return ial unless ial == Identity::IAL2 && service_provider.liveness_checking_required
    Identity::IAL2_STRICT
  end

  private

  attr_reader :ial, :service_provider

  def int_ial(input)
    Integer(input)
  rescue TypeError # input was nil
    nil
  rescue ArgumentError # input was probably a string
    Saml::Idp::Constants::AUTHN_CONTEXT_CLASSREF_TO_IAL.fetch(input)
  end
end
