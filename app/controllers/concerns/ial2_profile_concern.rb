module Ial2ProfileConcern
  extend ActiveSupport::Concern

  def cache_active_profile(raw_password)
    cacher = Pii::Cacher.new(current_user, user_session)
    profile = current_user.decorate.active_or_pending_profile
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
