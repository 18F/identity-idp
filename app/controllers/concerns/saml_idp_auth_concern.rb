module SamlIdpAuthConcern
  extend ActiveSupport::Concern

  included do
    before_action :validate_saml_request, only: :auth
    before_action :verify_authn_context, only: :auth
    before_action :store_saml_request_in_session, only: :auth
    before_action :confirm_two_factor_authenticated, only: :auth
  end

  private

  def verify_authn_context
    return if Saml::Idp::Constants::VALID_AUTHNCONTEXTS.include?(requested_authn_context)

    process_invalid_authn_context
  end

  # stores original SAMLRequest in session to continue SAML Authn flow
  def store_saml_request_in_session
    session[:saml_request_url] = request.original_url
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
    authn_context = requested_authn_context

    IdentityLinker.new(current_user, provider, authn_context).link_identity
  end

  def identity_needs_verification?
    loa3_requested? && identity_not_verified?
  end

  def loa3_requested?
    requested_authn_context == Saml::Idp::Constants::LOA3_AUTHNCONTEXT_CLASSREF
  end

  def identity_not_verified?
    UserDecorator.new(current_user).identity_not_verified?
  end

  def active_identity
    current_user.last_identity
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
    ServiceProvider.new(saml_request.service_provider.identifier)
  end
end
