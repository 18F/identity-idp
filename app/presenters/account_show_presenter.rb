# frozen_string_literal: true

class AccountShowPresenter
  attr_reader :user,
              :decrypted_pii,
              :locked_for_session,
              :pii,
              :sp_session_request_url,
              :authn_context,
              :sp_name

  delegate :identity_verified_with_biometric_comparison?, to: :user

  def initialize(
    decrypted_pii:,
    sp_session_request_url:,
    authn_context:,
    sp_name:,
    user:,
    locked_for_session:
  )
    @decrypted_pii = decrypted_pii
    @user = user
    @sp_name = sp_name
    @sp_session_request_url = sp_session_request_url
    @authn_context = authn_context
    @locked_for_session = locked_for_session
    @pii = determine_pii
  end

  def show_password_reset_partial?
    user.password_reset_profile.present?
  end

  def show_manage_personal_key_partial?
    user.encrypted_recovery_code_digest.present? &&
      user.password_reset_profile.blank?
  end

  def show_service_provider_continue_partial?
    sp_name.present? && sp_session_request_url.present?
  end

  def showing_alerts?
    show_service_provider_continue_partial? ||
      show_password_reset_partial?
  end

  def active_profile?
    user.active_profile.present?
  end

  def active_profile_for_authn_context?
    return @active_profile_for_authn_context if defined?(@active_profile_for_authn_context)

    @active_profile_for_authn_context = active_profile? && (
      !authn_context.biometric_comparison? || identity_verified_with_biometric_comparison?
    )
  end

  def pending_idv?
    authn_context.identity_proofing? && !active_profile_for_authn_context?
  end

  def pending_ipp?
    in_person_enrollment = user&.in_person_enrollments&.first
    if in_person_enrollment&.expired?
      user.pending_in_person_enrollment.present?
    elsif in_person_enrollment&.cancelled?
      user.pending_in_person_enrollment.present?
    elsif in_person_enrollment&.failed?
      user.pending_in_person_enrollment.present?
    else
      !!user.pending_profile&.in_person_verification_pending?
    end
  end

  def pending_gpo?
    !!user.pending_profile&.gpo_verification_pending?
  end

  def show_idv_partial?
    active_profile? || pending_idv? || pending_ipp? || pending_gpo?
  end

  def formatted_ipp_due_date
    I18n.l(user.pending_in_person_enrollment.due_date, format: :event_date)
  end

  def formatted_nonbiometric_idv_date
    I18n.l(user.active_profile.created_at, format: :event_date)
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
  ).freeze

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
    return PiiAccessor.new unless active_profile?
    if decrypted_pii.present? && !@locked_for_session
      decrypted_pii_accessor
    else
      obfuscated_pii_accessor
    end
  end
end
