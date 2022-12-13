# The WebauthnVerificationForm class is responsible for validating webauthn verification input
class WebauthnVerificationForm
  include ActiveModel::Model

  validates :user, presence: true
  validates :challenge, presence: true
  validates :authenticator_data, presence: true
  validates :client_data_json, presence: true
  validates :signature, presence: true

  attr_accessor :webauthn_configuration

  def initialize(user, user_session)
    @user = user
    @challenge = user_session[:webauthn_challenge]
    @authenticator_data = nil
    @client_data_json = nil
    @signature = nil
    @credential_id = nil
    @webauthn_configuration = nil
    @webauthn_errors = nil
  end

  def submit(protocol, params)
    consume_parameters(params)
    success = valid? && valid_assertion_response?(protocol)
    FormResponse.new(
      success: success,
      errors: errors,
      extra: extra_analytics_attributes,
    )
  end

  # this gives us a hook to override the domain embedded in the attestation test object
  def self.domain_name
    IdentityConfig.store.domain_name
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
    @webauthn_errors = params[:errors]
  end

  def valid_assertion_response?(protocol)
    return false if @webauthn_errors.present?
    assertion_response = ::WebAuthn::AuthenticatorAssertionResponse.new(
      authenticator_data: Base64.decode64(@authenticator_data),
      client_data_json: Base64.decode64(@client_data_json),
      signature: Base64.decode64(@signature),
    )
    original_origin = "#{protocol}#{self.class.domain_name}"
    @webauthn_configuration = user.webauthn_configurations.find_by(credential_id: @credential_id)
    return false unless @webauthn_configuration

    public_key = @webauthn_configuration.credential_public_key

    begin
      assertion_response.valid?(
        @challenge.pack('c*'),
        original_origin,
        public_key: Base64.decode64(public_key),
        sign_count: 0,
      )
    rescue OpenSSL::PKey::PKeyError
      false
    end
  end

  def extra_analytics_attributes
    auth_method = if @webauthn_configuration&.platform_authenticator
                    'webauthn_platform'
                  else
                    'webauthn'
                  end

    {
      multi_factor_auth_method: auth_method,
      webauthn_configuration_id: @webauthn_configuration&.id,
    }
  end
end
