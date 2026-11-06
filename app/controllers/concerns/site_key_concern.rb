# frozen_string_literal: true

module SiteKeyConcern
  extend ActiveSupport::Concern

  # Opens the person's site key with the password just entered, creating one for a listed
  # client. Before the second factor (`repair: false`) a wrap that fails to open is only marked
  # unavailable; once the person is fully authenticated it is replaced.
  def unlock_site_key(password, create: site_key_wanted?, repair: true)
    site_key_vault.unlock(password, create:)
    site_key_vault.clear_unavailable
  rescue SiteKeys::MismatchError => err
    return replace_site_key(password, create:, error: err) if repair

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

  # A wrap that fails under a password the person has just proven is stale: the password changed
  # while the key was locked. Unless a concurrent password change explains it, start over.
  def replace_site_key(password, create:, error:)
    replace = User.find(current_user.id).valid_password?(password)
    analytics.site_key_unlock_failed(error: error.message, replaced: replace)
    return site_key_vault.mark_unavailable unless replace

    site_key_vault.replace!(password, create:)
    site_key_vault.clear_unavailable
  rescue Encryption::EncryptionError, ActiveRecord::ActiveRecordError
    site_key_vault.mark_unavailable
  end
end
