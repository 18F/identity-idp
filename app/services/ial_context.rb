# Wraps up logic for querying the IAL level of an authorization request
class IalContext
  attr_reader :ial, :service_provider, :user, :authn_context_comparison

  # @param ial [String, Integer] IAL level as either an integer (see ::Idp::Constants::IAL2, etc)
  #   or a string see Saml::Idp::Constants contexts
  # @param service_provider [ServiceProvider, nil]
  def initialize(ial:, service_provider:, user: nil, authn_context_comparison: nil)
    @authn_context_comparison = authn_context_comparison
    @service_provider = service_provider
    @user = user
    @ial = int_ial(ial)
  end

  def ial2_service_provider?
    service_provider&.ial.to_i >= ::Idp::Constants::IAL2
  end

  def default_to_ial2?
    ial.nil? && ial2_service_provider?
  end

  def user_ial2_verified?
    user&.active_profile&.verified_at != nil
  end

  def ialmax_requested?
    ial&.zero?
  end

  def bill_for_ial_1_or_2
    ial2_or_greater? ? 2 : 1
  end

  def ial2_requested?
    (ialmax_requested? && user_ial2_verified?) || ial == ::Idp::Constants::IAL2
  end

  def ial2_or_greater?
    ial2_requested? || ial2_strict_requested? || default_to_ial2?
  end

  def ial2_strict_requested?
    ial == ::Idp::Constants::IAL2_STRICT
  end

  private

  def int_ial(input)
    return 0 if saml_ialmax?(input)

    convert_ial_to_int(input)
  end

  def saml_ialmax?(input)
    int_ial_from_request = convert_ial_to_int(input)
    return false unless int_ial_from_request.present?

    service_provider&.ial == 2 && authn_context_comparison == 'minimum' && int_ial_from_request < 2
  end

  def convert_ial_to_int(input)
    Integer(input)
  rescue TypeError # input was nil
    nil
  rescue ArgumentError # input was probably a string
    Saml::Idp::Constants::AUTHN_CONTEXT_CLASSREF_TO_IAL.fetch(input)
  end
end
