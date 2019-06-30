class OpenidConnectTokenForm # rubocop:disable Metrics/ClassLength
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper
  include Rails.application.routes.url_helpers

  ATTRS = %i[
    client_assertion
    client_assertion_type
    code
    code_verifier
    grant_type
  ].freeze

  attr_reader(*ATTRS)

  CLIENT_ASSERTION_TYPE = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'.freeze

  validates_inclusion_of :grant_type, in: %w[authorization_code]
  validates_inclusion_of :client_assertion_type,
                         in: [CLIENT_ASSERTION_TYPE],
                         if: :private_key_jwt?

  validate :validate_code
  validate :validate_pkce_or_private_key_jwt
  validate :validate_code_verifier, if: :pkce?
  validate :validate_client_assertion, if: :private_key_jwt?

  def initialize(params)
    ATTRS.each do |key|
      instance_variable_set(:"@#{key}", params[key])
    end
    @identity = find_identity_with_code
  end

  def submit
    success = valid?

    clear_authorization_code if success

    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  def response
    if valid?
      {
        access_token: identity.access_token,
        token_type: 'Bearer',
        expires_in: Pii::SessionStore.new(identity.rails_session_id).ttl,
        id_token: IdTokenBuilder.new(identity: identity, code: code).id_token,
      }
    else
      { error: errors.to_a.join(' ') }
    end
  end

  private

  attr_reader :identity

  def find_identity_with_code
    return if code.blank?

    session_expiration = Figaro.env.session_timeout_in_minutes.to_i.minutes.ago
    @identity = Identity.where(session_uuid: code).
                where('updated_at >= ?', session_expiration).
                order(updated_at: :desc).first
  end

  def pkce?
    pkce_sp && (code_verifier.present? || identity.try(:code_challenge).present?)
  end

  def private_key_jwt?
    non_pkce_sp && (client_assertion.present? || client_assertion_type.present?)
  end

  def non_pkce_sp
    !service_provider.pkce
  end

  def pkce_sp
    pkce = service_provider.pkce
    pkce.nil? || pkce
  end

  def validate_pkce_or_private_key_jwt
    return if pkce? || private_key_jwt?
    errors.add :code, t('openid_connect.token.errors.invalid_authentication')
  end

  def validate_code
    errors.add :code, t('openid_connect.token.errors.invalid_code') if identity.blank? ||
                                                                       !identity.user
  end

  def validate_code_verifier
    expected_code_challenge = remove_base64_padding(identity.try(:code_challenge))
    given_code_challenge = remove_base64_padding(Digest::SHA256.base64digest(code_verifier.to_s))
    return if expected_code_challenge == given_code_challenge
    errors.add :code_verifier, t('openid_connect.token.errors.invalid_code_verifier')
  end

  def validate_client_assertion
    return if identity.blank?

    payload, _headers = JWT.decode(client_assertion, service_provider.ssl_cert.public_key, true,
                                   algorithm: 'RS256', verify_iat: true,
                                   iss: client_id, verify_iss: true,
                                   sub: client_id, verify_sub: true)
    validate_aud_claim(payload)
  rescue JWT::DecodeError => err
    errors.add(:client_assertion, err.message)
  end

  def validate_aud_claim(payload)
    normalized_aud = payload['aud'].to_s.chomp('/')
    return if api_openid_connect_token_url == normalized_aud

    errors.add(:client_assertion,
               t('openid_connect.token.errors.invalid_aud', url: api_openid_connect_token_url))
  end

  def service_provider
    @service_provider ||= ServiceProvider.from_issuer(client_id)
  end

  def client_id
    identity.try(:service_provider)
  end

  def remove_base64_padding(data)
    Base64.urlsafe_encode64(Base64.urlsafe_decode64(data.to_s), padding: false)
  rescue ArgumentError
    nil
  end

  def extra_analytics_attributes
    {
      client_id: client_id,
      user_id: identity&.user&.uuid,
    }
  end

  def clear_authorization_code
    identity.update(session_uuid: nil)
  end
end
