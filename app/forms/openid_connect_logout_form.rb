class OpenidConnectLogoutForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper

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

  validate :validate_redirect_uri
  validate :validate_identity

  def initialize(params)
    ATTRS.each do |key|
      instance_variable_set(:"@#{key}", params[key])
    end

    @identity = load_identity
    @openid_connect_redirector = build_openid_connect_redirector
  end

  def submit
    @success = valid?

    identity.deactivate if success

    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  private

  attr_reader :identity,
              :openid_connect_redirector,
              :success

  def load_identity
    payload, _headers = JWT.decode(id_token_hint, RequestKeyManager.private_key.public_key, true,
                                   algorithm: 'RS256',
                                   leeway: Float::INFINITY).map(&:with_indifferent_access)

    identity_from_payload(payload)
  rescue JWT::DecodeError
    nil
  end

  def identity_from_payload(payload)
    uuid = payload[:sub]
    sp = payload[:aud]
    AgencyIdentityLinker.sp_identity_from_uuid_and_sp(uuid, sp)
  end

  def build_openid_connect_redirector
    OpenidConnectRedirector.new(
      redirect_uri: post_logout_redirect_uri,
      service_provider: service_provider,
      state: state,
      errors: errors,
      error_attr: :post_logout_redirect_uri
    )
  end

  def validate_redirect_uri
    openid_connect_redirector.validate
  end

  def validate_identity
    errors.add(:id_token_hint, t('openid_connect.logout.errors.id_token_hint')) unless identity
  end

  def service_provider
    @_service_provider ||= ServiceProvider.from_issuer(identity&.service_provider)
  end

  def extra_analytics_attributes
    {
      client_id: service_provider.issuer,
      redirect_uri: redirect_uri,
      sp_initiated: true,
      oidc: true,
    }
  end

  def redirect_uri
    if success
      openid_connect_redirector.logout_redirect_uri
    else
      openid_connect_redirector.error_redirect_uri
    end
  end
end
