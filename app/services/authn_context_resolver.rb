# frozen_string_literal: true

class AuthnContextResolver
  # @return [User]
  attr_reader :user

  # @return [ServiceProvider]
  attr_reader :service_provider

  # @return [Array<String>]
  attr_reader :vtr

  # @return [String]
  attr_reader :acr_values

  def initialize(user:, service_provider:, vtr:, acr_values:)
    @user = user
    @service_provider = service_provider
    @vtr = vtr
    @acr_values = initialize_acr_values(acr_values)
  end

  def resolve
    if vtr.present?
      selected_vtr_parser_result_from_vtr_list
    else
      acr_result_with_sp_defaults
    end
  end

  private


  def selected_vtr_parser_result_from_vtr_list
    if biometric_proofing_vot.present? && user&.identity_verified_with_biometric_comparison?
      biometric_proofing_vot
    elsif non_biometric_identity_proofing_vot.present? && user&.identity_verified?
      non_biometric_identity_proofing_vot
    elsif no_identity_proofing_vot.present?
      no_identity_proofing_vot
    else
      parsed_vectors_of_trust.first
    end
  end

  # @return [Array<Vot::Parser::Result>]
  def parsed_vectors_of_trust
    @parsed_vectors_of_trust ||= vtr.map do |vot|
      Vot::Parser.new(vector_of_trust: vot).parse
    end
  end

  def biometric_proofing_vot
    parsed_vectors_of_trust.find(&:biometric_comparison?)
  end

  def non_biometric_identity_proofing_vot
    parsed_vectors_of_trust.find do |vot_parser_result|
      vot_parser_result.identity_proofing? && !vot_parser_result.biometric_comparison?
    end
  end

  def no_identity_proofing_vot
    parsed_vectors_of_trust.find do |vot_parser_result|
      !vot_parser_result.identity_proofing?
    end
  end

  # Returns a copy of acr_values where the appropriate IAL authentication context class reference
  # name replaces <tt>Saml::Idp::Constants::IAL2_BIO_PREFERRED_AUTHN_CONTEXT_CLASSREF</tt>.
  # @note This implementation will be replaced with a more robust long-term
  # solution.
  # @param [String] acr_values
  def initialize_acr_values(acr_values)
    if sp_in_biometric_pilot? && acr_values.present?
      biometric_proofing_requested = acr_values.include?(Saml::Idp::Constants::IAL2_BIO_PREFERRED_AUTHN_CONTEXT_CLASSREF)
      if biometric_proofing_requested && user&.identity_verified_with_biometric_comparison?
        acr_values.gsub(
          Saml::Idp::Constants::IAL2_BIO_PREFERRED_AUTHN_CONTEXT_CLASSREF,
          Saml::Idp::Constants::IAL2_BIO_REQUIRED_AUTHN_CONTEXT_CLASSREF
        )
      elsif biometric_proofing_requested && user&.identity_verified?
        acr_values.gsub(
          Saml::Idp::Constants::IAL2_BIO_PREFERRED_AUTHN_CONTEXT_CLASSREF,
          Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF
        )
      end
    else
      acr_values
    end
  end

  def acr_result_with_sp_defaults
    decorate_acr_result_with_sp_defaults(
        acr_result_without_sp_defaults
    )
  end

  # @param [Vot::Parser::Result] result Parser result to decorate.
  # @return [Vot::Parser::Result]
  def decorate_acr_result_with_sp_defaults(result)
    result_with_sp_aal_defaults(
      result_with_sp_ial_defaults(
         result
        ),
      )
  end

  def acr_result_without_sp_defaults
    @acr_result_without_sp_defaults ||= Vot::Parser.new(acr_values: acr_values).parse
  end

  # @param result [Vot::Parser::Result]
  def result_with_sp_aal_defaults(result)
    if acr_aal_component_values.any?
      result
    elsif service_provider&.default_aal.to_i == 2
      result.with(aal2?: true)
    elsif service_provider&.default_aal.to_i >= 3
      result.with(aal2?: true, phishing_resistant?: true)
    else
      result
    end
  end

  # @param result [Vot::Parser::Result]
  def result_with_sp_ial_defaults(result)
    if acr_ial_component_values.any?
      result
    elsif service_provider&.ial.to_i >= 2
      result.with(identity_proofing?: true, aal2?: true)
    else
      result
    end
  end

  def acr_aal_component_values
    acr_result_without_sp_defaults.component_values.filter do |component_value|
      component_value.name.include?('aal') ||
        component_value.name == Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF
    end
  end

  def acr_ial_component_values
    acr_result_without_sp_defaults.component_values.filter do |component_value|
      component_value.name.include?('ial') || component_value.name.include?('loa')
    end
  end

  def sp_in_biometric_pilot?
    @service_provider.biometric_ial_allowed?
  end
end
