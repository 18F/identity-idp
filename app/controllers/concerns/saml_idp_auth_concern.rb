module SamlIdpAuthConcern
  extend ActiveSupport::Concern

  included do
    before_action :validate_saml_request, only: :auth
    before_action :validate_service_provider_and_authn_context, only: :auth
    before_action :add_sp_metadata_to_session, only: :auth
    before_action :confirm_two_factor_authenticated, only: :auth
  end

  private

  def validate_service_provider_and_authn_context
    @result = SamlRequestValidator.new.call(
      service_provider: current_service_provider,
      authn_context: requested_authn_context
    )

    return unless @result[:errors].present?

    analytics.track_event(Analytics::SAML_AUTH, @result)
    render nothing: true, status: :unauthorized
  end

  def add_sp_metadata_to_session
    session[:sp] = { loa3: loa3_requested?,
                     logo: current_sp_metadata[:logo],
                     return_url: current_sp_metadata[:return_to_sp_url],
                     name: current_sp_metadata[:friendly_name] ||
                           current_sp_metadata[:agency] }
  end

  def requested_authn_context
    @requested_authn_context ||= saml_request.requested_authn_context
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
    @_sp ||= ServiceProvider.new(saml_request.service_provider.identifier)
  end

  def current_sp_metadata
    current_service_provider.metadata
  end
end
