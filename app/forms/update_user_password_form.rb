# frozen_string_literal: true

class UpdateUserPasswordForm
  include ActiveModel::Model
  include FormPasswordValidator

  delegate :personal_key, to: :encryptor

  def initialize(user:, user_session: nil, required_password_change: false)
    @user = user
    @user_session = user_session
    @required_password_change = required_password_change
    @validate_confirmation = true
  end

  def submit(params)
    @password = params[:password]
    @password_confirmation = params[:password_confirmation]
    success = valid?
    process_valid_submission if success
    FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
  end

  private

  attr_reader :user, :user_session, :required_password_change

  def process_valid_submission
    vault = SiteKeys::Vault.new(user:, user_session: user_session || {})
    expected_fingerprint = vault.stored_fingerprint
    rewrapped_root = rewrap_site_key_root(vault)
    ActiveRecord::Base.transaction do
      user.update!(password: password)
      vault.store_root_or_forget!(rewrapped_root, expected_fingerprint:)
    end
    encrypt_user_profiles
  end

  # A root that cannot be re-wrapped right now is deleted rather than left behind wrapped under
  # the old password.
  def rewrap_site_key_root(vault)
    vault.wrap_cached_root(password)
  rescue Encryption::EncryptionError
    nil
  end

  def encrypt_user_profiles
    return if user.active_or_pending_profile.blank?

    encryptor.encrypt
    encrypt_attempt_events
  end

  def encryptor
    @encryptor ||= UserProfilesEncryptor.new(
      user: user,
      user_session: user_session,
      password: password,
    )
  end

  def extra_analytics_attributes
    {
      active_profile_present: user.active_profile.present?,
      pending_profile_present: user.pending_profile.present?,
      user_id: user.uuid,
      required_password_change: required_password_change,
    }
  end

  def encrypt_attempt_events
    return if user.active_profile.blank?
    return if user_session.blank?

    decrypted_events = AttemptsApi::Cacher.new(user, user_session).fetch
    return if decrypted_events.blank?

    user
      .active_profile
      .reencrypt_user_proofing_events(password:, personal_key:, attempt_events: decrypted_events)
  end
end
