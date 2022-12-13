module SamlIdpAuthConcern
  extend ActiveSupport::Concern
  extend Forwardable

  included do
    # rubocop:disable Rails/LexicallyScopedActionFilter
    before_action :validate_saml_request, only: :auth
    before_action :validate_service_provider_and_authn_context, only: :auth
    # this must take place _before_ the store_saml_request action or the SAML
    # request is cleared (along with the rest of the session) when the user is
    # signed out
    before_action :sign_out_if_forceauthn_is_true_and_user_is_signed_in, only: :auth
    before_action :store_saml_request, only: :auth
    before_action :check_sp_active, only: :auth
    # rubocop:enable Rails/LexicallyScopedActionFilter
  end

  private

  def sign_out_if_forceauthn_is_true_and_user_is_signed_in
    return unless user_signed_in? && saml_request.force_authn?

    if IdentityConfig.saml_internal_post
      sign_out unless SamlEndpoint.suffixes.find do |suffix|
        /finalauthpost#{suffix}$/.match?(request.path)
      end
    else
      sign_out unless sp_session[:request_url] == request.original_url
    end
  end

  def check_sp_active
    return if saml_request_service_provider&.active?
    redirect_to sp_inactive_error_url
  end

  def validate_service_provider_and_authn_context
    @saml_request_validator = SamlRequestValidator.new

    @result = @saml_request_validator.call(
      service_provider: saml_request_service_provider,
      authn_context: requested_authn_contexts,
      authn_context_comparison: saml_request.requested_authn_context_comparison,
      nameid_format: name_id_format,
    )

    return if @result.success?

    analytics.saml_auth(
      **@result.to_h.merge(request_signed: saml_request.signed?),
    )
    render 'saml_idp/auth/error', status: :bad_request
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

  def requested_aal_authn_context
    saml_request.requested_aal_authn_context || default_aal_context
  end

  def requested_ial_authn_context
    saml_request.requested_ial_authn_context || default_ial_context
  end

  def link_identity_from_session_data
    IdentityLinker.
      new(current_user, saml_request_service_provider).
      link_identity(
        ial: ial_context.ial,
        rails_session_id: session.id,
      )
  end

  def identity_needs_verification?
    ial2_requested? &&
      (current_user.decorate.identity_not_verified? ||
       current_user.decorate.reproof_for_irs?(service_provider: current_sp))
  end

  def_delegators :ial_context, :ial2_requested?

  def ial_context
    @ial_context ||= IalContext.new(
      ial: requested_ial_authn_context,
      service_provider: saml_request_service_provider,
      authn_context_comparison: saml_request.requested_authn_context_comparison,
      user: current_user,
    )
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
    cacher.fetch
  end

  def build_asserted_attributes(principal)
    asserter = attribute_asserter(principal)
    asserter.build
  end

  def saml_response
    encode_response(
      current_user,
      name_id_format: name_id_format,
      authn_context_classref: requested_aal_authn_context,
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
      cert = saml_request.service_provider.matching_cert ||
             saml_request_service_provider&.ssl_certs&.first
      {
        cert: cert,
        block_encryption: saml_request_service_provider&.block_encryption,
        key_transport: 'rsa-oaep-mgf1p',
      }
    end
  end

  def saml_response_signature_options
    endpoint = SamlEndpoint.new(request)
    {
      x509_certificate: endpoint.x509_certificate,
      secret_key: endpoint.secret_key,
    }
  end

  def saml_request_service_provider
    return @saml_request_service_provider if defined?(@saml_request_service_provider)
    @saml_request_service_provider = ServiceProvider.find_by(issuer: current_issuer)
  end

  def current_issuer
    @current_issuer ||= saml_request.service_provider&.identifier
  end

  def request_url
    url = URI.parse request.original_url
    url.path = remap_auth_post_path(url.path)
    query_params = Rack::Utils.parse_nested_query url.query
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

  def remap_auth_post_path(path)
    path_match = path.match(%r{/api/saml/authpost(?<year>\d{4})})
    return path unless path_match.present?

    "/api/saml/auth#{path_match[:year]}"
  end
end
