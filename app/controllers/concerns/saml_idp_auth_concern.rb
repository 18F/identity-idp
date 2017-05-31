module SamlIdpAuthConcern
  extend ActiveSupport::Concern

  included do
    before_action :validate_saml_request, only: :auth
    before_action :validate_service_provider_and_authn_context, only: :auth
    before_action :store_saml_request, only: :auth
    before_action :add_sp_metadata_to_session, only: :auth
  end

  private

  def validate_service_provider_and_authn_context
    @result = SamlRequestValidator.new.call(
      service_provider: current_service_provider,
      authn_context: requested_authn_context
    )

    return if @result.success?

    analytics.track_event(Analytics::SAML_AUTH, @result.to_h)
    render nothing: true, status: :unauthorized
  end

  def store_saml_request
    return if sp_session[:request_id]

    @request_id = SecureRandom.uuid
    ServiceProviderRequest.find_or_create_by(uuid: @request_id) do |sp_request|
      sp_request.issuer = current_issuer
      sp_request.loa = requested_authn_context
      sp_request.url = request.original_url
    end
  end

  def add_sp_metadata_to_session
    return if sp_session[:request_id]

    session[:sp] = {
      issuer: current_issuer,
      loa3: loa3_requested?,
      request_id: @request_id,
      request_url: request.original_url,
    }
  end

  def requested_authn_context
    @requested_authn_context ||= saml_request.requested_authn_context || default_authn_context
  end

  def default_authn_context
    Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF
  end

  def link_identity_from_session_data
    IdentityLinker.new(current_user, current_issuer).link_identity
  end

  def identity_needs_verification?
    loa3_requested? && current_user.decorate.identity_not_verified?
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
      decrypted_pii: decrypted_pii
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
      encryption: current_service_provider.encryption_opts
    )
  end

  def current_service_provider
    @_sp ||= ServiceProvider.from_issuer(current_issuer)
  end

  def current_issuer
    @_issuer ||= saml_request.service_provider.identifier
  end
end
