class OpenidConnectTokenForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper
  include Rails.application.routes.url_helpers

  ISSUED_AT_LEEWAY_SECONDS = 10.seconds.to_i

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

  validate :validate_expired
  validate :validate_code
  validate :validate_pkce_or_private_key_jwt
  validate :validate_code_verifier, if: :pkce?
  validate :validate_client_assertion, if: :private_key_jwt?

  def initialize(params)
    ATTRS.each do |key|
      instance_variable_set(:"@#{key}", params[key])
    end
    @session_expiration = IdentityConfig.store.session_timeout_in_minutes.minutes.ago
    @identity = find_identity_with_code
  end

  def submit
    success = valid?

    clear_authorization_code if success

    FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
  end

  def response
    if valid?
      id_token_builder = IdTokenBuilder.new(identity: identity, code: code)

      {
        access_token: identity.access_token,
        token_type: 'Bearer',
        expires_in: id_token_builder.ttl,
        id_token: id_token_builder.id_token,
      }
    else
      { error: errors.to_a.join(' ') }
    end
  end

  def url_options
    {}
  end

  private

  attr_reader :identity, :session_expiration

  def find_identity_with_code
    return if code.blank? || code.include?("\x00")

    # mattw: Add .consented here but this breaks 27 test cases, and I want to look at that tomorrow with
    # a fresher brain.
    @identity = ServiceProviderIdentity.where(session_uuid: code).
      order(updated_at: :desc).first
  end

  def pkce?
    pkce_sp && (code_verifier.present? || identity.try(:code_challenge).present?)
  end

  def private_key_jwt?
    non_pkce_sp && (client_assertion.present? || client_assertion_type.present?)
  end

  def non_pkce_sp
    !service_provider&.pkce
  end

  def pkce_sp
    pkce = service_provider&.pkce
    pkce.nil? || pkce
  end

  def validate_pkce_or_private_key_jwt
    return if pkce? || private_key_jwt?
    errors.add :code,
               t('openid_connect.token.errors.invalid_authentication'),
               type: :invalid_authentication
  end

  def validate_expired
    if identity&.updated_at && identity.updated_at < session_expiration
      errors.add :code, t('openid_connect.token.errors.expired_code'), type: :expired_code
    end
  end

  def validate_code
    if identity.blank? || !identity.user
      errors.add :code,
                 t('openid_connect.token.errors.invalid_code'),
                 type: :invalid_code
    end
  end

  def validate_code_verifier
    expected_code_challenge = remove_base64_padding(identity.try(:code_challenge))
    given_code_challenge = Digest::SHA256.urlsafe_base64digest(code_verifier.to_s)
    if expected_code_challenge &&
       given_code_challenge &&
       ActiveSupport::SecurityUtils.secure_compare(expected_code_challenge, given_code_challenge)
      return
    end
    errors.add :code_verifier,
               t('openid_connect.token.errors.invalid_code_verifier'),
               type: :invalid_code_verifier
  end

  def validate_client_assertion
    return if identity.blank?

    payload, _headers, err = nil

    matching_cert = service_provider&.ssl_certs&.find do |ssl_cert|
      err = nil
      payload, _headers = JWT.decode(
        client_assertion, ssl_cert.public_key, true,
        algorithm: 'RS256', iss: client_id,
        verify_iss: true, sub: client_id,
        verify_sub: true
      )
    rescue JWT::DecodeError => err
      next
    end

    if matching_cert && payload
      validate_aud_claim(payload)
      validate_iat(payload)
    else
      errors.add(
        :client_assertion,
        err&.message || t('openid_connect.token.errors.invalid_signature'),
        type: :invalid_signature,
      )
    end
  end

  def validate_aud_claim(payload)
    aud_claim = payload['aud']
    aud_as_array = Array.wrap(aud_claim)
    aud_as_array.map! { |aud| aud.to_s.chomp('/') }
    return true if aud_as_array.include?(api_openid_connect_token_url)

    errors.add(
      :client_assertion,
      t('openid_connect.token.errors.invalid_aud', url: api_openid_connect_token_url),
      type: :invalid_aud,
    )
  end

  def validate_iat(payload)
    return true unless payload.key?('iat')
    iat = payload['iat']
    return true if iat.is_a?(Numeric) && (iat.to_i - ISSUED_AT_LEEWAY_SECONDS) < Time.zone.now.to_i

    errors.add(
      :client_assertion, t('openid_connect.token.errors.invalid_iat'),
      type: :invalid_iat
    )
  end

  def service_provider
    return @service_provider if defined?(@service_provider)
    @service_provider = ServiceProvider.find_by(issuer: client_id)
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
      code_digest: code ? Digest::SHA256.hexdigest(code) : nil,
    }
  end

  def clear_authorization_code
    identity.update(session_uuid: nil)
  end
end
