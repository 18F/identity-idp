module Ial2ProfileConcern
  extend ActiveSupport::Concern

  def cache_profiles(raw_password)
    pending_profile = current_user.pending_profile
    if pending_profile.present?
      cache_profile_and_handle_errors(raw_password, pending_profile)
    end

    active_profile = current_user.active_profile
    if active_profile.present?
      cache_profile_and_handle_errors(raw_password, active_profile)
    end
  end

  private

  def cache_profile_and_handle_errors(raw_password, profile)
    cacher = Pii::Cacher.new(current_user, user_session)
    begin
      cacher.save(raw_password, profile)
    rescue Encryption::EncryptionError => err
      if profile
        profile.deactivate(:encryption_error)
        analytics.profile_encryption_invalid(error: err.message)
      end
    end
  end
end
