# frozen_string_literal: true

# Wraps up logic for querying the IAL level of an authorization request
class IalContext
  attr_reader :ial, :service_provider, :user

  # @param ial [String, Integer] IAL level as either an integer (see ::Idp::Constants::IAL2, etc)
  #   or a string see Saml::Idp::Constants contexts
  # @param service_provider [ServiceProvider, nil]
  def initialize(ial:, service_provider:, user: nil)
    @service_provider = service_provider
    @user = user
    @ial = convert_ial_to_int(ial)
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
    ial2_requested? || default_to_ial2?
  end

  private

  def convert_ial_to_int(input)
    Integer(input)
  rescue TypeError # input was nil
    nil
  rescue ArgumentError # input was probably a string
    Saml::Idp::Constants::AUTHN_CONTEXT_CLASSREF_TO_IAL.fetch(input)
  end
end
