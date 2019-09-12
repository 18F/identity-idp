module SamlIdpAuthConcern
  extend ActiveSupport::Concern

  included do
    # rubocop:disable Rails/LexicallyScopedActionFilter
    before_action :validate_saml_request, only: :auth
    before_action :validate_service_provider_and_authn_context, only: :auth
    before_action :store_saml_request, only: :auth
    # rubocop:enable Rails/LexicallyScopedActionFilter
  end

  private

  def validate_service_provider_and_authn_context
    @saml_request_validator = SamlRequestValidator.new

    @result = @saml_request_validator.call(
      service_provider: current_service_provider,
      authn_context: requested_authn_context,
      nameid_format: saml_request.name_id_format,
    )

    return if @result.success?

    analytics.track_event(Analytics::SAML_AUTH, @result.to_h)
    render 'saml_idp/auth/error', status: :bad_request
  end

  def store_saml_request
    ServiceProviderRequestHandler.new(
      url: request.original_url,
      session: session,
      protocol_request: saml_request,
      protocol: FederatedProtocols::Saml,
    ).call
  end

  def requested_authn_context
    @requested_authn_context ||= saml_request.requested_authn_context || default_authn_context
  end

  def default_authn_context
    Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF
  end

  def link_identity_from_session_data
    IdentityLinker.new(current_user, current_issuer).link_identity(ial: ial_level)
  end

  def identity_needs_verification?
    loa3_requested? && current_user.decorate.identity_not_verified?
  end

  def ial_level
    loa3_requested? ? 3 : 1
  end

  def loa3_requested?
    requested_authn_context == Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF
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
      service_provider: current_service_provider,
      authn_request: saml_request,
      decrypted_pii: decrypted_pii,
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
      authn_context_classref: requested_authn_context,
      reference_id: active_identity.session_uuid,
      encryption: current_service_provider.encryption_opts,
      signature: saml_response_signature_options,
    )
  end

  # :reek:FeatureEnvy
  def saml_response_signature_options
    endpoint = SamlEndpoint.new(request)
    {
      x509_certificate: endpoint.x509_certificate,
      secret_key: endpoint.secret_key,
      cloudhsm_key_label: endpoint.cloudhsm_key_label,
    }
  end

  def current_service_provider
    @_sp ||= ServiceProvider.from_issuer(current_issuer)
  end

  def current_issuer
    @_issuer ||= saml_request.service_provider.identifier
  end
end
