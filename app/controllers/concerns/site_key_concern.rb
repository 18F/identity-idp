# frozen_string_literal: true

module SiteKeyConcern
  extend ActiveSupport::Concern

  # Before the second factor (`repair: false`) a failing root is only marked unavailable; it is
  # replaced or repaired only once the user is fully authenticated.
  def unlock_site_key_root(password, create: site_key_root_wanted?, repair: true)
    site_key_vault.unlock(password, create:, show_recovery_code: repair, repair:)
    site_key_vault.clear_unavailable
  rescue SiteKeys::RootMismatchError => err
    return handle_site_key_root_mismatch(password, err) if repair

    analytics.site_key_root_unlock_failed(error: err.message, root_replaced: false)
    site_key_vault.mark_unavailable
  rescue Encryption::EncryptionError => err
    analytics.site_key_root_unlock_failed(error: err.message, root_replaced: false)
    site_key_vault.mark_unavailable
  end

  def site_key_root_wanted?
    current_sp&.site_key_allowed? == true
  end

  def site_key_vault
    @site_key_vault ||= SiteKeys::Vault.new(user: current_user, user_session:, analytics:)
  end

  private

  # Every password change re-wraps the root or drops its password wrap, so a password wrap that
  # fails to authenticate under a just-verified password is corrupt. Unless a concurrent
  # password change explains it, fall back to the recovery code, or start a new root when
  # nothing else can open it.
  def handle_site_key_root_mismatch(password, err)
    expected_fingerprint = site_key_vault.stored_fingerprint
    password_current = User.find(current_user.id).valid_password?(password)
    recoverable = current_user.site_key_root&.recoverable? == true
    replace = password_current && !recoverable
    analytics.site_key_root_unlock_failed(error: err.message, root_replaced: replace)
    return site_key_vault.mark_unavailable unless password_current

    if replace
      site_key_vault.replace!(password, expected_fingerprint:)
    else
      site_key_vault.forget_dead_password_wrap!(expected_fingerprint:)
    end
    site_key_vault.clear_unavailable
  rescue Encryption::EncryptionError, ActiveRecord::ActiveRecordError
    site_key_vault.mark_unavailable
  end
end
