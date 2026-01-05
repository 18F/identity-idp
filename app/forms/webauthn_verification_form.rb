# frozen_string_literal: true

# The WebauthnVerificationForm class is responsible for validating webauthn verification input
class WebauthnVerificationForm
  include ActiveModel::Model
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::TranslationHelper
  include Rails.application.routes.url_helpers

  validates :screen_lock_error,
            absence: { message: proc { |object| object.send(:screen_lock_error_message) } }
  validates :challenge,
            :authenticator_data,
            :client_data_json,
            :signature,
            :webauthn_configuration,
            presence: { message: proc { |object| object.send(:generic_error_message) } }
  validates :webauthn_error,
            absence: { message: proc { |object| object.send(:generic_error_message) } }
  validate :validate_assertion_response

  attr_reader :url_options, :platform_authenticator

  alias_method :platform_authenticator?, :platform_authenticator

  def initialize(
    user:,
    platform_authenticator:,
    url_options:,
    protocol:,
    challenge: nil,
    authenticator_data: nil,
    client_data_json: nil,
    signature: nil,
    credential_id: nil,
    webauthn_error: nil,
    screen_lock_error: nil
  )
    @user = user
    @platform_authenticator = platform_authenticator
    @url_options = url_options
    @protocol = protocol
    @challenge = challenge
    @protocol = protocol
    @authenticator_data = authenticator_data
    @client_data_json = client_data_json
    @signature = signature
    @credential_id = credential_id
    @webauthn_error = webauthn_error
    @screen_lock_error = screen_lock_error
  end

  def submit
    success = valid?
    FormResponse.new(
      success: success,
      errors: errors,
      extra: extra_analytics_attributes,
    )
  end

  def webauthn_configuration
    return @webauthn_configuration if defined?(@webauthn_configuration)
    @webauthn_configuration = user.webauthn_configurations.find_by(credential_id: credential_id)
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
              :webauthn_error,
              :screen_lock_error

  def validate_assertion_response
    return if webauthn_error.present? || webauthn_configuration.blank? || valid_assertion_response?
    errors.add(:authenticator_data, :invalid_authenticator_data, message: generic_error_message)
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
      [original_origin],
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

  def generic_error_message
    if platform_authenticator?
      t(
        'two_factor_authentication.webauthn_error.try_again',
        link: link_to(
          t('two_factor_authentication.webauthn_error.additional_methods_link'),
          login_two_factor_options_path,
        ),
      )
    else
      t(
        'two_factor_authentication.webauthn_error.connect_html',
        link_html: link_to(
          t('two_factor_authentication.webauthn_error.additional_methods_link'),
          login_two_factor_options_path,
        ),
      )
    end
  end

  def screen_lock_error_message
    if user_has_other_authentication_method?
      t(
        'two_factor_authentication.webauthn_error.screen_lock_other_mfa_html',
        link_html: link_to(
          t('two_factor_authentication.webauthn_error.use_a_different_method'),
          login_two_factor_options_path,
        ),
      )
    else
      t(
        'two_factor_authentication.webauthn_error.screen_lock_no_other_mfa',
        link_html: link_to(
          t('two_factor_authentication.webauthn_error.use_a_different_method'),
          login_two_factor_options_path,
        ),
      )
    end
  end

  def aaguid
    aaguid ||= webauthn_configuration&.aaguid
    return aaguid if aaguid.present?

    # If not stored, extract it from the current authenticator data
    extract_aaguid_from_authenticator_data
  end

  def extract_aaguid_from_authenticator_data
    return nil if authenticator_data.blank?

    begin
      decoded_data = Base64.decode64(authenticator_data)
      # AAGUID is at bytes 37-52 (16 bytes) in the authenticator data
      # Structure: RP ID Hash (32) + Flags (1) + Sign Count (4) + AAGUID (16) + ...
      return nil if decoded_data.bytesize < 53
      
      aaguid_bytes = decoded_data[37, 16]
      format_aaguid(aaguid_bytes.unpack1('H*'))
    rescue StandardError => e
      nil
    end
  end

  def format_aaguid(hex_string)
    # Format as: 8-4-4-4-12 (e.g., fbfc3007-154e-4ecc-8c0b-6e020557d7bd)
    return nil if hex_string.blank? || hex_string.length != 32
    "#{hex_string[0, 8]}-#{hex_string[8, 4]}-#{hex_string[12, 4]}-#{hex_string[16, 4]}-#{hex_string[20, 12]}".downcase
  end

  def user_has_other_authentication_method?
    MfaContext.new(user).two_factor_configurations.any? do |configuration|
      !configuration.is_a?(WebauthnConfiguration) ||
        configuration.platform_authenticator? != platform_authenticator?
    end
  end

  def extra_analytics_attributes
    {
      webauthn_configuration_id: webauthn_configuration&.id,
      frontend_error: webauthn_error.presence,
      webauthn_aaguid: webauthn_configuration&.aaguid,
    }
  end
end
