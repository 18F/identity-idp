# The WebauthnVerificationForm class is responsible for validating webauthn verification input
class WebauthnVerificationForm
  include ActiveModel::Model

  validates :user, presence: true
  validates :challenge, presence: true
  validates :authenticator_data, presence: true
  validates :client_data_json, presence: true
  validates :signature, presence: true

  def initialize(user, user_session)
    @user = user
    @challenge = user_session[:webauthn_challenge]
    @authenticator_data = nil
    @client_data_json = nil
    @signature = nil
    @credential_id = nil
  end

  def submit(protocol, params)
    consume_parameters(params)
    success = valid? && valid_assertion_response?(protocol)
    FormResponse.new(
      success: success,
      errors: errors.messages,
      extra: extra_analytics_attributes,
    )
  end

  # this gives us a hook to override the domain embedded in the attestation test object
  def self.domain_name
    Figaro.env.domain_name
  end

  private

  attr_reader :success,
              :user,
              :challenge,
              :authenticator_data,
              :client_data_json,
              :signature

  def consume_parameters(params)
    @authenticator_data = params[:authenticator_data]
    @client_data_json = params[:client_data_json]
    @signature = params[:signature]
    @credential_id = params[:credential_id]
  end

  def valid_assertion_response?(protocol)
    assertion_response = ::WebAuthn::AuthenticatorAssertionResponse.new(
      authenticator_data: Base64.decode64(@authenticator_data),
      client_data_json: Base64.decode64(@client_data_json),
      signature: Base64.decode64(@signature),
      credential_id: Base64.decode64(@credential_id),
    )
    original_origin = "#{protocol}#{self.class.domain_name}"
    assertion_response.valid?(@challenge.pack('c*'), original_origin,
                              allowed_credentials: [allowed_credential])
  end

  def allowed_credential
    {
      id: Base64.decode64(@credential_id),
      public_key: Base64.decode64(public_key),
    }
  end

  def public_key
    WebauthnConfiguration.
      where(user_id: user.id, credential_id: @credential_id).take.credential_public_key
  end

  def extra_analytics_attributes
    {
      multi_factor_auth_method: 'webauthn',
    }
  end
end
