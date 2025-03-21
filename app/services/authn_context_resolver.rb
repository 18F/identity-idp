# frozen_string_literal: true

class AuthnContextResolver
  attr_reader :user, :service_provider, :vtr, :acr_values

  def initialize(user:, service_provider:, vtr:, acr_values:)
    @user = user
    @service_provider = service_provider
    @vtr = vtr
    @acr_values = acr_values
  end

  def result
    @result ||= if vtr.present?
                  selected_vtr_parser_result_from_vtr_list
                else
                  acr_result
                end
  end

  def asserted_ial_acr
    return resolve_acr(Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF) unless
      user&.identity_verified?

    if result.facial_match?
      resolve_acr(Saml::Idp::Constants::IAL2_BIO_REQUIRED_AUTHN_CONTEXT_CLASSREF)
    elsif result.identity_proofing? ||
          result.ialmax?
      resolve_acr(Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF)
    else
      resolve_acr(Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF)
    end
  end

  def asserted_aal_acr
    if result.hspd12?
      Saml::Idp::Constants::AAL2_HSPD12_AUTHN_CONTEXT_CLASSREF
    elsif result.phishing_resistant?
      Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF
    elsif result.aal2?
      Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF
    else
      Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF
    end
  end

  private

  def selected_vtr_parser_result_from_vtr_list
    if facial_match_proofing_vot.present? && user&.identity_verified_with_facial_match?
      facial_match_proofing_vot
    elsif non_facial_match_identity_proofing_vot.present? && user&.identity_verified?
      non_facial_match_identity_proofing_vot
    elsif no_identity_proofing_vot.present?
      no_identity_proofing_vot
    else
      parsed_vectors_of_trust.first
    end
  end

  def parsed_vectors_of_trust
    @parsed_vectors_of_trust ||= vtr.map do |vot|
      Vot::Parser.new(vector_of_trust: vot).parse
    end
  end

  def facial_match_proofing_vot
    parsed_vectors_of_trust.find(&:facial_match?)
  end

  def non_facial_match_identity_proofing_vot
    parsed_vectors_of_trust.find do |vot_parser_result|
      vot_parser_result.identity_proofing? && !vot_parser_result.facial_match?
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
    maybe_force_ial2_acr_result(
      result_with_sp_aal_defaults(
        result_with_sp_ial_defaults(
          acr_result_without_sp_defaults,
        ),
      ),
    )
  end

  def acr_result_without_sp_defaults
    @acr_result_without_sp_defaults ||= Vot::Parser.new(acr_values: acr_values).parse
  end

  def maybe_force_ial2_acr_result(result)
    return result if !service_provider&.force_ial2_allowed?
    return result if !result.identity_proofing?

    result.with(facial_match?: true)
  end

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

  def decorate_acr_result_with_user_context(result)
    return result unless result.facial_match?

    return result if user&.identity_verified_with_facial_match? ||
                     facial_match_is_required?(result)

    if user&.identity_verified?
      result.with(facial_match?: false, two_pieces_of_fair_evidence?: false)
    else
      result.with(facial_match?: true)
    end
  end

  def result_with_sp_ial_defaults(result)
    if acr_ial_component_values.any?
      result
    elsif service_provider&.identity_proofing_allowed?
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
      Saml::Idp::Constants::AUTHN_CONTEXT_CLASSREF_TO_IAL.include?(component_value.name)
    end
  end

  def resolve_acr(acr)
    return acr unless use_semantic_authn_contexts?
    Saml::Idp::Constants::LEGACY_ACRS_TO_SEMANTIC_ACRS.fetch(acr, default_value: acr)
  end

  def facial_match_is_required?(result)
    Saml::Idp::Constants::FACIAL_MATCH_REQUIRED_IAL_CONTEXTS.intersect?(result.component_names) ||
      service_provider.force_ial2_allowed?
  end

  def use_semantic_authn_contexts?
    @use_semantic_authn_contexts ||= Vot::AcrComponentValues.any_semantic_acrs?(acr_values)
  end
end
