# The WebauthnVerificationForm class is responsible for validating webauthn verification input
class WebauthnVerificationForm
  include ActiveModel::Model

  validates :user, presence: true
  validates :challenge, presence: true
  validates :authenticator_data, presence: true
  validates :client_data_json, presence: true
  validates :signature, presence: true
  validates :webauthn_configuration, presence: true
  validate :validate_assertion_response
  validate :validate_webauthn_error

  def initialize(
    protocol:,
    user: nil,
    challenge: nil,
    authenticator_data: nil,
    client_data_json: nil,
    signature: nil,
    credential_id: nil,
    webauthn_error: nil
  )
    @user = user
    @challenge = challenge
    @protocol = protocol
    @authenticator_data = authenticator_data
    @client_data_json = client_data_json
    @signature = signature
    @credential_id = credential_id
    @webauthn_error = webauthn_error
  end

  def submit
    success = valid?
    FormResponse.new(
      success: success,
      errors: errors,
      extra: extra_analytics_attributes,
      serialize_error_details_only: true,
    )
  end

  def webauthn_configuration
    return @webauthn_configuration if defined?(@webauthn_configuration)
    @webauthn_configuration = user&.webauthn_configurations&.find_by(credential_id: credential_id)
  end

  # this gives us a hook to override the domain embedded in the attestation test object
  def self.domain_name
    IdentityConfig.store.domain_name
  end

  private

  attr_reader :user,
              :challenge,
              :protocol,
              :authenticator_data,
              :client_data_json,
              :signature,
              :credential_id,
              :webauthn_error

  def validate_assertion_response
    return if webauthn_error.present? || webauthn_configuration.blank? || valid_assertion_response?
    errors.add(:authenticator_data, :invalid_authenticator_data, type: :invalid_authenticator_data)
  end

  def validate_webauthn_error
    return if webauthn_error.blank?
    errors.add(:webauthn_error, webauthn_error, type: :webauthn_error)
  end

  def valid_assertion_response?
    return false if authenticator_data.blank? ||
                    client_data_json.blank? ||
                    signature.blank? ||
                    challenge.blank?
    WebAuthn::AuthenticatorAssertionResponse.new(
      authenticator_data: Base64.decode64(authenticator_data),
      client_data_json: Base64.decode64(client_data_json),
      signature: Base64.decode64(signature),
    ).valid?(
      challenge.pack('c*'),
      original_origin,
      public_key: Base64.decode64(public_key),
      sign_count: 0,
    )
  rescue OpenSSL::PKey::PKeyError
    false
  end

  def original_origin
    "#{protocol}#{self.class.domain_name}"
  end

  def public_key
    webauthn_configuration&.credential_public_key
  end

  def extra_analytics_attributes
    auth_method = if webauthn_configuration&.platform_authenticator
                    'webauthn_platform'
                  else
                    'webauthn'
                  end

    {
      multi_factor_auth_method: auth_method,
      webauthn_configuration_id: webauthn_configuration&.id,
    }
  end
end
