class AccountShow
  attr_reader :decorated_user, :decrypted_pii, :personal_key, :locked_for_session, :pii

  def initialize(decrypted_pii:, personal_key:, decorated_user:, locked_for_session:)
    @decrypted_pii = decrypted_pii
    @personal_key = personal_key
    @decorated_user = decorated_user
    @locked_for_session = locked_for_session
    @pii = determine_pii
  end

  def show_personal_key_partial?
    personal_key.present?
  end

  def show_password_reset_partial?
    decorated_user.password_reset_profile.present?
  end

  def pending_profile_partial
    if decorated_user.pending_profile_requires_verification?
      if decorated_user.usps_mail_bounced?
        'accounts/pending_profile_bounced_usps'
      else
        'accounts/pending_profile_usps'
      end
    else
      'shared/null'
    end
  end

  def unphishable_badge_partial
    return 'shared/null' unless MfaPolicy.new(decorated_user.user).unphishable?
    'accounts/unphishable_badge'
  end

  def verified_account_badge_partial
    return 'shared/null' unless decorated_user.identity_verified?
    'accounts/verified_account_badge'
  end

  def edit_action_partial
    'accounts/actions/edit_action_button'
  end

  def manage_action_partial
    'accounts/actions/manage_action_button'
  end

  def delete_action_partial
    'accounts/actions/delete_action_button'
  end

  def show_pii_partial?
    decrypted_pii.present? || decorated_user.identity_verified?
  end

  def totp_partial
    if TwoFactorAuthentication::AuthAppPolicy.new(decorated_user.user).enabled?
      disable_totp_partial
    else
      enable_totp_partial
    end
  end

  def disable_totp_partial
    return 'shared/null' unless MfaPolicy.new(decorated_user.user).multiple_factors_enabled?
    'accounts/actions/disable_totp'
  end

  def enable_totp_partial
    'accounts/actions/enable_totp'
  end

  def piv_cac_partial
    if TwoFactorAuthentication::PivCacPolicy.new(decorated_user.user).enabled?
      disable_piv_cac_partial
    else
      enable_piv_cac_partial
    end
  end

  def disable_piv_cac_partial
    return 'shared/null' unless MfaPolicy.new(decorated_user.user).multiple_factors_enabled?
    'accounts/actions/disable_piv_cac'
  end

  def enable_piv_cac_partial
    'accounts/actions/enable_piv_cac'
  end

  def show_manage_personal_key_partial?
    if TwoFactorAuthentication::PersonalKeyPolicy.new(decorated_user.user).visible? &&
       decorated_user.password_reset_profile.blank?
      true
    else
      false
    end
  end

  def backup_codes_partial
    if TwoFactorAuthentication::BackupCodePolicy.new(decorated_user.user).configured?
      regenerate_backup_codes_partial
    else
      generate_backup_codes_partial
    end
  end

  def regenerate_backup_codes_partial
    'accounts/actions/regenerate_backup_codes'
  end

  def generate_backup_codes_partial
    'accounts/actions/generate_backup_codes'
  end

  def backup_codes_generated_at
    decorated_user.user.backup_code_configurations.order(created_at: :asc).first&.created_at
  end

  def header_personalization
    return decrypted_pii.first_name if decrypted_pii.present?

    EmailContext.new(decorated_user.user).last_sign_in_email_address.email
  end

  def totp_content
    if TwoFactorAuthentication::AuthAppPolicy.new(decorated_user.user).enabled?
      I18n.t('account.index.auth_app_enabled')
    else
      I18n.t('account.index.auth_app_disabled')
    end
  end

  def piv_cac_content
    if TwoFactorAuthentication::PivCacPolicy.new(decorated_user.user).enabled?
      I18n.t('account.index.piv_cac_enabled')
    else
      I18n.t('account.index.piv_cac_disabled')
    end
  end

  delegate :recent_events, :recent_devices, :connected_apps, to: :decorated_user

  private

  PiiAccessor = Struct.new(:obfuscated,
                           :full_name,
                           :address1,
                           :address2,
                           :city,
                           :state,
                           :zipcode,
                           :dob,
                           :phone,
                           keyword_init: true)

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
      dob: @decrypted_pii.dob.to_date.to_formatted_s(:long),
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
