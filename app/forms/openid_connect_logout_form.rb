class OpenidConnectLogoutForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper
  include RedirectUriValidator

  ATTRS = %i[
    id_token_hint
    post_logout_redirect_uri
    state
  ].freeze

  attr_reader(*ATTRS)

  RANDOM_VALUE_MINIMUM_LENGTH = OpenidConnectAuthorizeForm::RANDOM_VALUE_MINIMUM_LENGTH

  validates :id_token_hint, presence: true
  validates :post_logout_redirect_uri, presence: true
  validates :state, presence: true, length: { minimum: RANDOM_VALUE_MINIMUM_LENGTH }

  validate :validate_identity

  def initialize(params)
    ATTRS.each do |key|
      instance_variable_set(:"@#{key}", params[key])
    end

    @identity = load_identity
  end

  def submit
    @success = valid?

    identity.deactivate if success

    FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
  end

  private

  attr_reader :identity,
              :success

  def load_identity
    payload, _headers = JWT.decode(
      id_token_hint, AppArtifacts.store.oidc_public_key, true,
      algorithm: 'RS256',
      leeway: Float::INFINITY
    ).map(&:with_indifferent_access)

    identity_from_payload(payload)
  rescue JWT::DecodeError
    nil
  end

  def identity_from_payload(payload)
    uuid = payload[:sub]
    sp = payload[:aud]
    AgencyIdentityLinker.sp_identity_from_uuid_and_sp(uuid, sp)
  end

  def validate_identity
    unless identity
      errors.add(
        :id_token_hint, t('openid_connect.logout.errors.id_token_hint'),
        type: :id_token_hint
      )
    end
  end

  # Used by RedirectUriValidator
  def service_provider
    identity&.service_provider_record
  end

  def extra_analytics_attributes
    {
      client_id: identity&.service_provider,
      redirect_uri: redirect_uri,
      sp_initiated: true,
      oidc: true,
    }
  end

  def redirect_uri
    success ? logout_redirect_uri : error_redirect_uri
  end

  def logout_redirect_uri
    uri = post_logout_redirect_uri unless errors.include?(:redirect_uri)

    UriService.add_params(uri, state: state)
  end

  def error_redirect_uri
    uri = post_logout_redirect_uri unless errors.include?(:redirect_uri)

    UriService.add_params(
      uri,
      error: 'invalid_request',
      error_description: errors.full_messages.join(' '),
      state: state,
    )
  end
end
