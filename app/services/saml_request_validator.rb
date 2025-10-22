# frozen_string_literal: true

class SamlRequestValidator
  include ActiveModel::Model

  validate :basic_saml_checks_pass
  validate :request_cert_exists
  validate :authorized_service_provider
  validate :registered_cert_exists
  validate :authorized_authn_context
  validate :authorized_email_nameid_format

  def initialize(blank_cert: false, saml_errors: [])
    @blank_cert = blank_cert
    @saml_errors = saml_errors
  end

  def call(service_provider:, authn_context:, nameid_format:, authn_context_comparison: nil)
    self.service_provider = service_provider
    self.authn_context = Array(authn_context)
    self.authn_context_comparison = authn_context_comparison || 'exact'
    self.nameid_format = nameid_format

    FormResponse.new(success: valid?, errors: errors, extra: extra_analytics_attributes)
  end

  private

  attr_accessor :service_provider, :authn_context, :authn_context_comparison, :nameid_format,
                :saml_errors

  # rubocop:disable IdentityIdp/ErrorsAddLinter
  def basic_saml_checks_pass
    return if saml_errors.empty?

    saml_errors.each { |error| errors.add(:service_provider, error) }
  end
  # rubocop:enable IdentityIdp/ErrorsAddLinter

  def extra_analytics_attributes
    {
      nameid_format: nameid_format,
      authn_context: authn_context,
      authn_context_comparison: authn_context_comparison,
      service_provider: service_provider&.issuer,
    }
  end

  # This checks that the SP matches something in the database
  # SamlIdpAuthConcern#check_sp_active checks that it's currently active
  def authorized_service_provider
    return if service_provider
    errors.add(
      :service_provider, :unauthorized_service_provider
    )
  end

  def authorized_authn_context
    # if there is no service provider, an error has already been added
    return unless service_provider.present?

    if !valid_authn_context? ||
       (identity_proofing_requested? && !service_provider.identity_proofing_allowed?) ||
       (ial_max_requested? && !service_provider.ialmax_allowed?) ||
       (facial_match_ial_requested? && !service_provider.facial_match_ial_allowed?)
      errors.add(:authn_context, :unauthorized_authn_context)
    end
  end

  def registered_cert_exists
    # if there is no service provider, an error has already been added
    return if service_provider.blank?
    return if service_provider.certs.present?
    return unless service_provider.encrypt_responses?

    errors.add(:service_provider, :no_cert_registered)
  end

  def request_cert_exists
    if @blank_cert
      errors.add(:service_provider, :blank_cert_element_req)
    end
  end

  def valid_authn_context?
    valid_contexts = Saml::Idp::Constants::VALID_AUTHN_CONTEXTS.dup
    valid_contexts += Saml::Idp::Constants::PASSWORD_AUTHN_CONTEXT_CLASSREFS if step_up_comparison?

    authn_contexts = authn_context.reject do |classref|
      next true if classref.include?(Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF)
    end

    # SAML requests are allowed to "default" to the integration's IAL default.
    return true if authn_contexts.empty?

    authn_contexts.any? do |classref|
      valid_contexts.include?(classref)
    end
  end

  def step_up_comparison?
    %w[minimum better].include? authn_context_comparison
  end

  def identity_proofing_requested?
    authn_context.each do |classref|
      return true if Saml::Idp::Constants::IAL2_AUTHN_CONTEXTS.include?(classref)
    end
    false
  end

  def ial_max_requested?
    Array(authn_context).include?(Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF)
  end

  def facial_match_ial_requested?
    Array(authn_context).any? { |ial| Saml::Idp::Constants::FACIAL_MATCH_IAL_CONTEXTS.include? ial }
  end

  def authorized_email_nameid_format
    return unless email_nameid_format?
    return if service_provider&.email_nameid_format_allowed

    errors.add(:nameid_format, :unauthorized_nameid_format)
  end

  def email_nameid_format?
    [
      'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress',
      'urn:oasis:names:tc:SAML:2.0:nameid-format:emailAddress',
    ].include?(nameid_format)
  end
end
