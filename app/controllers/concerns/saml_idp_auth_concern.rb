# frozen_string_literal: true

module SamlIdpAuthConcern
  extend ActiveSupport::Concern
  extend Forwardable
  include ForcedReauthenticationConcern

  included do
    # rubocop:disable Rails/LexicallyScopedActionFilter
    before_action :validate_year
    before_action :validate_and_create_saml_request_object, only: :auth
    before_action :validate_service_provider_and_authn_context, only: :auth
    before_action :check_sp_active, only: :auth
    before_action :log_external_saml_auth_request, only: [:auth]
    # this must take place _before_ the store_saml_request action or the SAML
    # request is cleared (along with the rest of the session) when the user is
    # signed out
    before_action :sign_out_if_forceauthn_is_true_and_user_is_signed_in, only: :auth
    before_action :store_saml_request, only: :auth
    # rubocop:enable Rails/LexicallyScopedActionFilter
  end

  private

  def validate_year
    if !SamlEndpoint.valid_year?(params[:path_year])
      render plain: 'Invalid Year', status: :bad_request
    end
  end

  def sign_out_if_forceauthn_is_true_and_user_is_signed_in
    if !saml_request.force_authn?
      set_issuer_forced_reauthentication(
        issuer: saml_request_service_provider.issuer,
        is_forced_reauthentication: false,
      )
    end

    return unless user_signed_in? && saml_request.force_authn?

    if !sp_session[:final_auth_request]
      sign_out
      set_issuer_forced_reauthentication(
        issuer: saml_request_service_provider.issuer,
        is_forced_reauthentication: true,
      )
    end
    sp_session[:final_auth_request] = false
  end

  def check_sp_active
    return if saml_request_service_provider&.active?
    redirect_to sp_inactive_error_url
  end

  def validate_service_provider_and_authn_context
    return if result.success?

    capture_analytics
    track_integration_errors(
      event: :saml_auth_request,
      errors: result.errors.values.flatten,
    )

    render 'saml_idp/auth/error', status: :bad_request
  end

  def result
    @result ||= @saml_request_validator.call(
      service_provider: saml_request_service_provider,
      authn_context: requested_authn_contexts,
      authn_context_comparison: saml_request.requested_authn_context_comparison,
      nameid_format: name_id_format,
    )
  end

  def validate_and_create_saml_request_object
    # this saml_idp method creates the saml_request object used for validations
    validate_saml_request
    @saml_request_validator = SamlRequestValidator.new
  rescue SamlIdp::XMLSecurity::SignedDocument::ValidationError
    @saml_request_validator = SamlRequestValidator.new(blank_cert: true)
  end

  def name_id_format
    @name_id_format ||= specified_name_id_format || default_name_id_format
  end

  def specified_name_id_format
    if recognized_name_id_format? || saml_request_service_provider&.use_legacy_name_id_behavior
      saml_request.name_id_format
    end
  end

  def recognized_name_id_format?
    Saml::Idp::Constants::VALID_NAME_ID_FORMATS.include?(saml_request.name_id_format)
  end

  def default_name_id_format
    if saml_request_service_provider&.email_nameid_format_allowed
      return Saml::Idp::Constants::NAME_ID_FORMAT_EMAIL
    end
    Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT
  end

  def store_saml_request
    ServiceProviderRequestHandler.new(
      url: request_url,
      session: session,
      protocol_request: saml_request,
      protocol: FederatedProtocols::Saml,
    ).call
  end

  def requested_authn_contexts
    @requested_authn_contexts ||= saml_request.requested_authn_contexts.presence ||
                                  [default_aal_context]
  end

  def default_aal_context
    if saml_request_service_provider&.default_aal
      Saml::Idp::Constants::AUTHN_CONTEXT_AAL_TO_CLASSREF[saml_request_service_provider.default_aal]
    else
      Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF
    end
  end

  def default_ial_context
    if saml_request_service_provider&.ial
      Saml::Idp::Constants::AUTHN_CONTEXT_IAL_TO_CLASSREF[saml_request_service_provider.ial]
    else
      Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF
    end
  end

  def response_authn_context
    if saml_request.requested_vtr_authn_contexts.present?
      resolved_authn_context_result.expanded_component_values
    else
      FederatedProtocols::Saml.new(saml_request).aal ||
        default_aal_context
    end
  end

  def link_identity_from_session_data
    IdentityLinker
      .new(current_user, saml_request_service_provider)
      .link_identity(
        ial: resolved_authn_context_int_ial,
        rails_session_id: session.id,
        email_address_id: email_address_id,
      )
  end

  def email_address_id
    identity = current_user.identities.find_by(service_provider: sp_session[:issuer])
    return nil if !identity&.verified_single_email_attribute?
    if user_session[:selected_email_id_for_linked_identity].present?
      return user_session[:selected_email_id_for_linked_identity]
    end
    email_id = identity&.email_address_id
    return email_id if email_id.is_a? Integer
  end

  def identity_needs_verification?
    resolved_authn_context_result.identity_proofing? && current_user.identity_not_verified?
  end

  def active_identity
    current_user.last_identity
  end

  def encode_authn_response(principal, opts)
    build_asserted_attributes(principal)
    super(principal, opts)
  end

  def attribute_asserter(principal)
    AttributeAsserter.new(
      user: principal,
      service_provider: saml_request_service_provider,
      name_id_format: name_id_format,
      authn_request: saml_request,
      decrypted_pii: decrypted_pii,
      user_session: user_session,
    )
  end

  def decrypted_pii
    cacher = Pii::Cacher.new(current_user, user_session)
    cacher.fetch(current_user&.active_profile&.id)
  end

  def build_asserted_attributes(principal)
    asserter = attribute_asserter(principal)
    asserter.build
  end

  def saml_response
    encode_response(
      current_user,
      name_id_format: name_id_format,
      authn_context_classref: response_authn_context,
      reference_id: active_identity.session_uuid,
      encryption: encryption_opts,
      signature: saml_response_signature_options,
      signed_response_message: saml_request_service_provider&.signed_response_message_requested,
    )
  end

  def encryption_opts
    query_params = UriService.params(request.original_url)
    if query_params[:skip_encryption].present? &&
       saml_request_service_provider&.skip_encryption_allowed
      nil
    elsif saml_request_service_provider&.encrypt_responses?
      {
        cert: encryption_cert,
        block_encryption: saml_request_service_provider&.block_encryption,
        key_transport: 'rsa-oaep-mgf1p',
      }
    end
  end

  def encryption_cert
    saml_request.matching_cert ||
      saml_request_service_provider&.ssl_certs&.first
  end

  def saml_response_signature_options
    endpoint = SamlEndpoint.new(params[:path_year])
    {
      x509_certificate: endpoint.x509_certificate,
      secret_key: endpoint.secret_key,
    }
  end

  def saml_request_service_provider
    return @saml_request_service_provider if defined?(@saml_request_service_provider)
    @saml_request_service_provider =
      if current_issuer.blank?
        nil
      else
        ServiceProvider.find_by(issuer: current_issuer)
      end
  end

  def current_issuer
    @current_issuer ||= saml_request.service_provider&.identifier
  end

  def request_url
    url = URI(api_saml_auth_url(path_year: params[:path_year]))

    query_params = request.query_parameters
    unless query_params['SAMLRequest']
      orig_saml_request = saml_request.options[:get_params][:SAMLRequest]
      query_params['SAMLRequest'] = orig_saml_request
    end
    unless query_params['RelayState']
      orig_relay_state = saml_request.options[:get_params][:RelayState]
      query_params['RelayState'] = orig_relay_state if orig_relay_state
    end

    url.query = Rack::Utils.build_query(query_params).presence
    url.to_s
  end

  def track_integration_errors(event:, errors: nil)
    analytics.sp_integration_errors_present(
      error_details: errors || saml_request.errors.uniq,
      error_types: [:saml_request_errors],
      event:,
      integration_exists: saml_request_service_provider.present?,
      request_issuer: saml_request&.issuer,
    )
  end
end
