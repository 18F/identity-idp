class WebauthnSetupForm
  include ActiveModel::Model

  validates :user, presence: true
  validates :challenge, presence: true
  validates :attestation_object, presence: true
  validates :client_data_json, presence: true
  validates :name, presence: true
  validate :name_is_unique

  attr_reader :attestation_response, :name_taken

  def initialize(user, user_session)
    @user = user
    @challenge = user_session[:webauthn_challenge]
    @attestation_object = nil
    @client_data_json = nil
    @attestation_response = nil
    @name = nil
    @platform_authenticator = false
  end

  def submit(protocol, params)
    consume_parameters(params)
    success = valid? && valid_attestation_response?(protocol)
    if success
      create_webauthn_configuration
      event = PushNotification::RecoveryInformationChangedEvent.new(user: user)
      PushNotification::HttpPush.deliver(event)
    end

    FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
  end

  # this gives us a hook to override the domain embedded in the attestation test object
  def self.domain_name
    IdentityConfig.store.domain_name
  end

  def platform_authenticator?
    !!@platform_authenticator
  end

  private

  attr_reader :success
  attr_accessor :user, :challenge, :attestation_object, :client_data_json,
                :name, :platform_authenticator

  def consume_parameters(params)
    @attestation_object = params[:attestation_object]
    @client_data_json = params[:client_data_json]
    @name = params[:name]
    @platform_authenticator = (params[:platform_authenticator].to_s == 'true')
  end

  def name_is_unique
    return unless WebauthnConfiguration.exists?(user_id: @user.id, name: @name)
    if @platform_authenticator
      errors.add :name, I18n.t('errors.webauthn_platform_setup.unique_name'), type: :unique_name
    else
      errors.add :name, I18n.t('errors.webauthn_setup.unique_name'), type: :unique_name
    end
    @name_taken = true
  end

  def valid_attestation_response?(protocol)
    @attestation_response = ::WebAuthn::AuthenticatorAttestationResponse.new(
      attestation_object: Base64.decode64(@attestation_object),
      client_data_json: Base64.decode64(@client_data_json),
    )
    safe_response("#{protocol}#{self.class.domain_name}")
  end

  def safe_response(original_origin)
    @attestation_response.valid?(@challenge.pack('c*'), original_origin)
  rescue StandardError
    if @platform_authenticator
      errors.add :name, I18n.t(
        'errors.webauthn_platform_setup.attestation_error',
        link: MarketingSite.contact_url,
      ), type: :attestation_error
    else
      errors.add :name, I18n.t(
        'errors.webauthn_setup.attestation_error',
        link: MarketingSite.contact_url,
      ), type: :attestation_error
    end
    false
  end

  def create_webauthn_configuration
    credential = attestation_response.credential
    public_key = Base64.strict_encode64(credential.public_key)
    id = Base64.strict_encode64(credential.id)
    user.webauthn_configurations.create(
      credential_public_key: public_key,
      credential_id: id,
      name: name,
      platform_authenticator: platform_authenticator,
    )
  end

  def mfa_user
    @mfa_user ||= MfaContext.new(user)
  end

  def extra_analytics_attributes
    auth_method = if platform_authenticator?
                    'webauthn_platform'
                  else
                    'webauthn'
                  end
    {
      mfa_method_counts: mfa_user.enabled_two_factor_configuration_counts_hash,
      enabled_mfa_methods_count: mfa_user.enabled_mfa_methods_count,
      multi_factor_auth_method: auth_method,
      pii_like_keypaths: [[:mfa_method_counts, :phone]],
    }
  end
end
