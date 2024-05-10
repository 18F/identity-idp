# frozen_string_literal: true

class SamlRequestValidator
  include ActiveModel::Model

  validate :cert_exists
  validate :authorized_service_provider
  validate :authorized_authn_context
  validate :parsable_vtr
  validate :authorized_nameid_format

  def initialize(blank_cert: false)
    @blank_cert = blank_cert
  end

  def call(service_provider:, authn_context:, nameid_format:, authn_context_comparison: nil)
    self.service_provider = service_provider
    self.authn_context = Array(authn_context)
    self.authn_context_comparison = authn_context_comparison || 'exact'
    self.nameid_format = nameid_format

    FormResponse.new(success: valid?, errors: errors, extra: extra_analytics_attributes)
  end

  def biometric_comparison_requested?
    !!parsed_vectors_of_trust&.any?(&:biometric_comparison?)
  end

  private

  attr_accessor :service_provider, :authn_context, :authn_context_comparison, :nameid_format

  def extra_analytics_attributes
    {
      nameid_format: nameid_format,
      authn_context: authn_context,
      authn_context_comparison: authn_context_comparison,
      service_provider: service_provider&.issuer,
    }
  end

  def parsed_vectors_of_trust
    return @parsed_vectors_of_trust if defined?(@parsed_vectors_of_trust)

    @parsed_vectors_of_trust = begin
      if vtr.is_a?(Array) && !vtr.empty?
        vtr.map { |vot| Vot::Parser.new(vector_of_trust: vot).parse }
      end
    rescue Vot::Parser::ParseException
      nil
    end
  end

  # This checks that the SP matches something in the database
  # SamlIdpAuthConcern#check_sp_active checks that it's currently active
  def authorized_service_provider
    return if service_provider
    errors.add(
      :service_provider, :unauthorized_service_provider,
      type: :unauthorized_service_provider
    )
  end

  def authorized_authn_context
    if !valid_authn_context? ||
       (identity_proofing_requested? && service_provider&.ial != 2) ||
       (ial_max_requested? &&
        !IdentityConfig.store.allowed_ialmax_providers.include?(service_provider&.issuer))
      errors.add(:authn_context, :unauthorized_authn_context, type: :unauthorized_authn_context)
    end
  end

  def parsable_vtr
    if !vtr.blank? && parsed_vectors_of_trust.blank?
      errors.add(:authn_context, :unauthorized_authn_context, type: :unauthorized_authn_context)
    end
  end

  def cert_exists
    if @blank_cert
      errors.add(:service_provider, :blank_cert_element_req, type: :blank_cert_element_req)
    end
  end

  def valid_authn_context?
    valid_contexts = Saml::Idp::Constants::VALID_AUTHN_CONTEXTS.dup
    valid_contexts += Saml::Idp::Constants::PASSWORD_AUTHN_CONTEXT_CLASSREFS if step_up_comparison?

    authn_contexts = authn_context.reject do |classref|
      next true if classref.include?(Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF)
      next true if classref.match?(SamlIdp::Request::VTR_REGEXP) &&
                   IdentityConfig.store.use_vot_in_sp_requests
    end
    authn_contexts.all? do |classref|
      valid_contexts.include?(classref)
    end
  end

  def step_up_comparison?
    %w[minimum better].include? authn_context_comparison
  end

  def identity_proofing_requested?
    return true if parsed_vectors_of_trust&.any?(&:identity_proofing?)

    authn_context.each do |classref|
      return true if Saml::Idp::Constants::IAL2_AUTHN_CONTEXTS.include?(classref)
    end
    false
  end

  def vtr
    @vtr ||= Array(authn_context).select do |classref|
      classref.match?(SamlIdp::Request::VTR_REGEXP)
    end
  end

  def ial_max_requested?
    Array(authn_context).include?(Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF)
  end

  def authorized_nameid_format
    return if satisfiable_nameid_format?
    return if email_nameid_format? && service_provider&.email_nameid_format_allowed
    return if legacy_name_id_behavior_needed?

    errors.add(:nameid_format, :unauthorized_nameid_format, type: :unauthorized_nameid_format)
  end

  def satisfiable_nameid_format?
    nameid_format.nil? || [Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT,
                           Saml::Idp::Constants::NAME_ID_FORMAT_UNSPECIFIED].include?(nameid_format)
  end

  def legacy_name_id_behavior_needed?
    service_provider&.use_legacy_name_id_behavior && !email_nameid_format?
  end

  def email_nameid_format?
    nameid_format == Saml::Idp::Constants::NAME_ID_FORMAT_EMAIL
  end
end
