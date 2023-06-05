class AccountShowPresenter
  attr_reader :user, :decrypted_pii, :personal_key, :locked_for_session, :pii,
              :sp_session_request_url, :sp_name

  def initialize(decrypted_pii:, personal_key:, sp_session_request_url:, sp_name:, user:,
                 locked_for_session:)
    @decrypted_pii = decrypted_pii
    @personal_key = personal_key
    @user = user
    @sp_name = sp_name
    @sp_session_request_url = sp_session_request_url
    @locked_for_session = locked_for_session
    @pii = determine_pii
  end

  def show_personal_key_partial?
    personal_key.present?
  end

  def show_password_reset_partial?
    user.password_reset_profile.present?
  end

  def show_pii_partial?
    decrypted_pii.present? || user.identity_verified?
  end

  def show_manage_personal_key_partial?
    user.encrypted_recovery_code_digest.present? &&
      user.password_reset_profile.blank?
  end

  def show_service_provider_continue_partial?
    sp_name.present? && sp_session_request_url.present?
  end

  def show_gpo_partial?
    user.gpo_verification_pending_profile?
  end

  def showing_any_partials?
    show_service_provider_continue_partial? ||
      show_password_reset_partial? ||
      show_personal_key_partial? ||
      show_gpo_partial?
  end

  def show_unphishable_badge?
    MfaPolicy.new(user).unphishable?
  end

  def show_verified_badge?
    user.identity_verified?
  end

  def showing_any_badges?
    show_unphishable_badge? || show_verified_badge?
  end

  def backup_codes_generated_at
    user.backup_code_configurations.order(created_at: :asc).first&.created_at
  end

  def personal_key_generated_at
    user.personal_key_generated_at
  end

  def header_personalization
    return decrypted_pii.first_name if decrypted_pii.present?

    EmailContext.new(user).last_sign_in_email_address.email
  end

  def totp_content
    if TwoFactorAuthentication::AuthAppPolicy.new(user).enabled?
      I18n.t('account.index.auth_app_enabled')
    else
      I18n.t('account.index.auth_app_disabled')
    end
  end

  delegate :recent_events, :recent_devices, :connected_apps, to: :user

  private

  PiiAccessor = RedactedStruct.new(
    :obfuscated,
    :full_name,
    :address1,
    :address2,
    :city,
    :state,
    :zipcode,
    :dob,
    :phone,
    keyword_init: true,
  )

  def obfuscated_pii_accessor
    PiiAccessor.new(
      obfuscated: true,
      full_name: '***** **********',
      address1: '*************************',
      address2: '*************',
      state: '**',
      zipcode: '*****',
      dob: '******* **, ****',
      phone: '**********',
    )
  end

  def decrypted_pii_accessor
    PiiAccessor.new(
      obfuscated: false,
      full_name: "#{@decrypted_pii.first_name} #{@decrypted_pii.last_name}",
      address1: @decrypted_pii.address1,
      address2: @decrypted_pii.address2,
      city: @decrypted_pii.city,
      state: @decrypted_pii.state,
      zipcode: @decrypted_pii.zipcode,
      dob: DateParser.parse_legacy(@decrypted_pii.dob).to_formatted_s(:long),
      phone: @decrypted_pii.phone,
    )
  end

  def determine_pii
    return PiiAccessor.new unless show_pii_partial?
    if decrypted_pii.present? && !@locked_for_session
      decrypted_pii_accessor
    else
      obfuscated_pii_accessor
    end
  end
end
