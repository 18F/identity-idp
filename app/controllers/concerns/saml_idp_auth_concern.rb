module SamlIdpAuthConcern
  extend ActiveSupport::Concern

  included do
    before_action :validate_saml_request, only: :auth
    before_action :validate_service_provider, only: :auth
    before_action :verify_authn_context, only: :auth
    before_action :store_saml_request_in_session, only: :auth
    before_action :confirm_two_factor_authenticated, only: :auth
  end

  private

  def verify_authn_context
    return if Saml::Idp::Constants::VALID_AUTHN_CONTEXTS.include?(requested_authn_context)

    process_invalid_authn_context
  end

  def validate_service_provider
    add_sp_metadata_to_session and return if current_service_provider.valid?

    analytics.track_event(
      :invalid_service_provider,
      service_provider: current_service_provider.issuer
    )

    render nothing: true, status: :unauthorized
  end

  # stores original SAMLRequest in session to continue SAML Authn flow
  def store_saml_request_in_session
    session[:saml_request_url] = request.original_url
  end

  def add_sp_metadata_to_session
    session[:sp] = { logo: current_sp_metadata[:logo],
                     return_url: current_sp_metadata[:return_to_sp_url],
                     name: current_sp_metadata[:friendly_name] ||
                           current_sp_metadata[:agency] }
  end

  def requested_authn_context
    @requested_authn_context ||= saml_request.requested_authn_context
  end

  def process_invalid_authn_context
    logger.info "Invalid authn context #{requested_authn_context} requested"
    render nothing: true, status: :bad_request
  end

  def link_identity_from_session_data
    provider = saml_request.service_provider.identifier

    IdentityLinker.new(current_user, provider).link_identity
  end

  def identity_needs_verification?
    loa3_requested? && decorated_user.identity_not_verified?
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

  def build_asserted_attributes(principal)
    asserter = attribute_asserter(principal)
    asserter.build
  end

  def attribute_asserter(principal)
    AttributeAsserter.new(principal, current_service_provider, saml_request)
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
    @_sp ||= ServiceProvider.new(saml_request.service_provider.identifier)
  end

  def current_sp_metadata
    current_service_provider.metadata
  end
end
