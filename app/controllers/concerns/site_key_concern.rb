# frozen_string_literal: true

module SiteKeyConcern
  extend ActiveSupport::Concern

  # Opens the person's site key with the password just entered, creating one for a listed client.
  # Before the second factor (`repair: false`) a wrap that fails to open is only marked
  # unavailable, and a freshly minted recovery code is not shown; once the person is fully
  # authenticated a stale password wrap is dropped and, when nothing else can open the key, a new
  # key is made.
  def unlock_site_key(password, create: site_key_wanted?, repair: true)
    site_key_vault.unlock(password, create:, show_recovery_code: repair)
    site_key_vault.clear_unavailable
  rescue SiteKeys::MismatchError => err
    return repair_site_key(password, create:, error: err) if repair

    analytics.site_key_unlock_failed(error: err.message, replaced: false)
    site_key_vault.mark_unavailable
  rescue Encryption::EncryptionError => err
    analytics.site_key_unlock_failed(error: err.message, replaced: false)
    site_key_vault.mark_unavailable
  end

  def site_key_wanted?
    current_sp&.site_key_allowed? == true
  end

  def site_key_vault
    @site_key_vault ||= SiteKeys::Vault.new(user: current_user, user_session:, analytics:)
  end

  private

  # A password wrap that fails under a password the person has just proven is stale: the password
  # changed while the key was locked. Unless a concurrent password change explains it, drop the
  # dead password wrap when the recovery code can still open the key, or start a new key when
  # nothing can.
  def repair_site_key(password, create:, error:)
    expected_fingerprint = site_key_vault.stored_fingerprint
    password_current = User.find(current_user.id).valid_password?(password)
    recoverable = current_user.site_key&.recoverable? == true
    analytics.site_key_unlock_failed(
      error: error.message,
      replaced: password_current && !recoverable,
    )
    return site_key_vault.mark_unavailable unless password_current

    if recoverable
      site_key_vault.forget_dead_password_wrap!(expected_fingerprint:)
    else
      site_key_vault.replace!(password, create:)
    end
    site_key_vault.clear_unavailable
  rescue Encryption::EncryptionError, ActiveRecord::ActiveRecordError
    site_key_vault.mark_unavailable
  end
end
