# Wraps up logic for querying the IAL level of an authorization request
class IalContext
  attr_reader :ial, :service_provider

  # @param ial [String, Integer] IAL level as either an integer (see ::Idp::Constants::IAL2, etc)
  #   or a string see Saml::Idp::Constants contexts
  # @param service_provider [ServiceProvider, nil]
  def initialize(ial:, service_provider:)
    @ial = int_ial(ial)
    @service_provider = service_provider
  end

  def ial2_service_provider?
    service_provider.ial.to_i >= ::Idp::Constants::IAL2
  end

  def ialmax_requested?
    ial&.zero?
  end

  def ial2_requested?
    ial == ::Idp::Constants::IAL2
  end

  def ial2_or_greater?
    ial2_requested? || ial2_strict_requested?
  end

  def ial2_strict_requested?
    ial == ::Idp::Constants::IAL2_STRICT ||
      (ial == ::Idp::Constants::IAL2 && service_provider_requires_liveness?)
  end

  def ial_for_identity_record
    return ial unless ial == ::Idp::Constants::IAL2 && service_provider_requires_liveness?
    ::Idp::Constants::IAL2_STRICT
  end

  private

  def service_provider_requires_liveness?
    !!service_provider && service_provider.liveness_checking_required
  end

  def int_ial(input)
    Integer(input)
  rescue TypeError # input was nil
    nil
  rescue ArgumentError # input was probably a string
    Saml::Idp::Constants::AUTHN_CONTEXT_CLASSREF_TO_IAL.fetch(input)
  end
end
