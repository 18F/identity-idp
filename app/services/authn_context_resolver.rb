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
    @acr_values = acr_values
  end

  def resolve
    if vtr.present?
      selected_vtr_parser_result_from_vtr_list
    elsif acr_values.present?
      acr_result
    else
      Vot::Parser::Result.no_sp_result
    end
  end

  def result
    @result ||= resolve
  end

  def asserted_ial_acr
    return if vtr.present?

    if result.biometric_comparison?
      Saml::Idp::Constants::IAL2_BIO_REQUIRED_AUTHN_CONTEXT_CLASSREF
    elsif result.identity_proofing?
      Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF
    else
      Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF
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

  def acr_result
    @acr_result ||= decorate_acr_result_with_user_context(
      acr_result_with_sp_defaults,
    )
  end

  def acr_result_with_sp_defaults
    @acr_result_with_sp_defaults ||= decorate_acr_result_with_sp_defaults(
      acr_result_without_sp_defaults,
    )
  end

  # @param [Vot::Parser::Result] result Parser result to decorate.
  # @return [Vot::Parser::Result]
  def decorate_acr_result_with_sp_defaults(result)
    result_with_sp_aal_defaults(
      result_with_sp_ial_defaults(
        result,
      ),
    )
  end

  # With a given {User}, assert the resolved IAL ACR value and corollary requirements
  #   1. If biometric proofing was requested and performed,
  #      then we return a value to indicate we performed biometric comparison.
  #   2. If identity proofing was requested and performed,
  #      then we return a value to indicate we performed identity proofing
  #   3. If we did not perform identity proofing,
  #      then it is IAL1
  # @param [Vot::Parser::Result] result Parser result to decorate.
  # @return [Vot::Parser::Result]
  def decorate_acr_result_with_user_context(result)
    if result.biometric_comparison? &&
       (user&.identity_verified_with_biometric_comparison? ||
         biometrics_comparison_required?)
      biometrics_proofing_acr_result(result)
    elsif result.identity_proofing_or_ialmax? && user&.identity_verified? ||
          result.identity_proofing? && sp_requires_identity_proofing?
      non_biometric_identity_proofing_acr_result(result)
    elsif no_identity_proofing_acr_component_values.any?
      no_identity_proofing_acr_result(result)
    else
      result
    end
  end

  def biometrics_proofing_acr_result(result)
    result.with(
      aal2?: true,
      identity_proofing?: true,
      biometric_comparison?: true,
      two_pieces_of_fair_evidence?: true,
    )
  end

  def non_biometric_identity_proofing_acr_result(result)
    result.with(
      aal2?: true,
      identity_proofing?: true,
      biometric_comparison?: false,
      two_pieces_of_fair_evidence?: false,
    )
  end

  def no_identity_proofing_acr_result(result)
    result.with(
      identity_proofing?: false,
      biometric_comparison?: false,
      two_pieces_of_fair_evidence?: false,
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
    elsif sp_requires_identity_proofing?
      result.with(identity_proofing?: true, aal2?: true)
    else
      result
    end
  end

  def assert_ial_with_loa_acr?
    acr_loa_component_values.any? &&
      acr_ial_component_values.length === acr_loa_component_values.size
  end

  def acr_aal_component_values
    @acr_aal_component_values ||=
      acr_result_without_sp_defaults.component_values.filter do |component_value|
        Saml::Idp::Constants::AUTHN_CONTEXT_CLASSREF_TO_AAL.include?(component_value.name)
      end
  end

  # @return [Array]
  def acr_ial_component_values
    @acr_ial_component_values ||=
      acr_result_without_sp_defaults.component_values.filter do |component_value|
        Saml::Idp::Constants::AUTHN_CONTEXT_CLASSREF_TO_IAL.include?(component_value.name)
      end
  end

  def no_identity_proofing_acr_component_values
    @no_identity_proofing_acr_component_values ||= acr_ial_component_values.filter do |c|
      Saml::Idp::Constants::NO_IDENTITY_PROOFING_AUTHN_CONTEXTS.include?(c.name)
    end
  end

  def sp_requires_identity_proofing?
    service_provider&.ial.to_i >= 2
  end

  def biometrics_comparison_required?
    acr_ial_component_values.any? do |c|
      c.name == Saml::Idp::Constants::IAL2_BIO_REQUIRED_AUTHN_CONTEXT_CLASSREF
    end
  end
end
