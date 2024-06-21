# frozen_string_literal: true

class WebauthnSetupForm
  include ActiveModel::Model

  validates :user,
            :challenge,
            :attestation_object,
            :client_data_json,
            :name,
            presence: { message: proc { |object| object.send(:generic_error_message) } }
  validate :name_is_unique
  validate :validate_attestation_response

  attr_reader :attestation_response

  def initialize(user:, user_session:, device_name:)
    @user = user
    @challenge = user_session[:webauthn_challenge]
    @attestation_object = nil
    @client_data_json = nil
    @attestation_response = nil
    @name = nil
    @platform_authenticator = false
    @authenticator_data_flags = nil
    @protocol = nil
    @device_name = device_name
  end

  def submit(params)
    consume_parameters(params)
    success = valid?
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

  def generic_error_message
    if platform_authenticator?
      I18n.t('errors.webauthn_platform_setup.general_error')
    else
      I18n.t(
        'errors.webauthn_setup.general_error_html',
        link_html: I18n.t('errors.webauthn_setup.additional_methods_link'),
      )
    end
  end

  private

  attr_reader :success, :transports, :invalid_transports, :protocol
  attr_accessor :user, :challenge, :attestation_object, :client_data_json,
                :name, :platform_authenticator, :authenticator_data_flags, :device_name

  def consume_parameters(params)
    @attestation_object = params[:attestation_object]
    @client_data_json = params[:client_data_json]
    @platform_authenticator = (params[:platform_authenticator].to_s == 'true')
    @name = @platform_authenticator ? @device_name : params[:name]
    @authenticator_data_flags = process_authenticator_data_value(
      params[:authenticator_data_value],
    )
    @transports, @invalid_transports = params[:transports]&.split(',')&.partition do |transport|
      WebauthnConfiguration::VALID_TRANSPORTS.include?(transport)
    end
    @protocol = params[:protocol]
  end

  def name_is_unique
    return unless WebauthnConfiguration.exists?(user_id: @user.id, name: @name)
    if @platform_authenticator
      num_existing_devices = WebauthnConfiguration.
        where(user_id: @user.id).
        where('name LIKE ?', "#{@name}%").
        count
      @name = "#{@name} (#{num_existing_devices})"
    else
      name_error = if platform_authenticator?
                     I18n.t('errors.webauthn_platform_setup.unique_name')
                   else
                     I18n.t('errors.webauthn_setup.unique_name')
                   end
      errors.add :name, name_error, type: :unique_name
    end
  end

  def validate_attestation_response
    return if valid_attestation_response?(protocol)
    errors.add :name, :attestation_error, message: general_error_message
  end

  def valid_attestation_response?(protocol)
    original_origin = "#{protocol}#{self.class.domain_name}"
    @attestation_response = ::WebAuthn::AuthenticatorAttestationResponse.new(
      attestation_object: Base64.decode64(@attestation_object),
      client_data_json: Base64.decode64(@client_data_json),
    )

    begin
      attestation_response.valid?(@challenge.pack('c*'), original_origin)
    rescue StandardError
      false
    end
  end

  def process_authenticator_data_value(data_value)
    data_int_value = Integer(data_value, 10)
    # bits defined using https://w3c.github.io/webauthn/#sctn-authenticator-data
    {
      up: (data_int_value & (1 << 0)).positive?,
      uv: (data_int_value & (1 << 2)).positive?,
      be: (data_int_value & (1 << 3)).positive?,
      bs: (data_int_value & (1 << 4)).positive?,
      at: (data_int_value & (1 << 6)).positive?,
      ed: (data_int_value & (1 << 7)).positive?,
    }
  rescue ArgumentError
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
      transports: transports.presence,
      authenticator_data_flags: authenticator_data_flags,
    )
  end

  def general_error_message
    if platform_authenticator
      I18n.t('errors.webauthn_platform_setup.general_error')
    else
      I18n.t(
        'errors.webauthn_setup.general_error_html',
        link_html: I18n.t('errors.webauthn_setup.additional_methods_link'),
      )
    end
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
      authenticator_data_flags: authenticator_data_flags,
      unknown_transports: invalid_transports.presence,
    }.compact
  end
end
