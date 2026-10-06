# frozen_string_literal: true

module SiteKeyConcern
  extend ActiveSupport::Concern

  # Before the second factor (`repair: false`) a failing root is only marked unavailable; it is
  # replaced or repaired only once the user is fully authenticated.
  def unlock_site_key_root(password, create: site_key_root_wanted?, repair: true)
    site_key_vault.unlock(password, create:)
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

  # Every password change re-wraps or deletes the root, so a wrap that fails to authenticate
  # under a just-verified password is corrupt and nothing else can open it. Unless a concurrent
  # password change explains it, start a new root.
  def handle_site_key_root_mismatch(password, err)
    replace = User.find(current_user.id).valid_password?(password)
    analytics.site_key_root_unlock_failed(error: err.message, root_replaced: replace)
    return site_key_vault.mark_unavailable unless replace

    site_key_vault.replace!(password)
    site_key_vault.clear_unavailable
  rescue Encryption::EncryptionError, ActiveRecord::ActiveRecordError
    site_key_vault.mark_unavailable
  end
end
