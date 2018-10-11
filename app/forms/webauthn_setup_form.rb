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
  end

  def submit(protocol, params)
    consume_parameters(params)
    success = valid? && valid_attestation_response?(protocol)
    FormResponse.new(success: success, errors: errors.messages)
  end

  # this gives us a hook to override the domain embedded in the attestation test object
  def self.domain_name
    Figaro.env.domain_name
  end

  private

  attr_reader :success
  attr_accessor :user, :challenge, :attestation_object, :client_data_json, :name

  def consume_parameters(params)
    @attestation_object = params[:attestation_object]
    @client_data_json = params[:client_data_json]
    @name = params[:name]
  end

  def name_is_unique
    return unless WebauthnConfiguration.exists?(user_id: @user.id, name: @name)
    errors.add :name, I18n.t('errors.webauthn_setup.unique_name')
    @name_taken = true
  end

  def valid_attestation_response?(protocol)
    @attestation_response = ::WebAuthn::AuthenticatorAttestationResponse.new(
      attestation_object: Base64.decode64(@attestation_object),
      client_data_json: Base64.decode64(@client_data_json)
    )
    original_origin = "#{protocol}#{self.class.domain_name}"
    @attestation_response.valid?(@challenge.pack('c*'), original_origin)
  end
end
