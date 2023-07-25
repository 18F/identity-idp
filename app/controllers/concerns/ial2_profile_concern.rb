module Ial2ProfileConcern
  extend ActiveSupport::Concern

  def cache_active_profile(raw_password)
    cacher = Pii::Cacher.new(current_user, user_session)
    profile = current_user.active_or_pending_profile
    begin
      cacher.save(raw_password, profile)
    rescue Encryption::EncryptionError => err
      if profile
        profile.deactivate(:encryption_error)
        analytics.profile_encryption_invalid(error: err.message)
      end
    end
  end

  def generate_pii_key_for_keyless_user(password)
    return unless current_user.password_pii_encryption_public_key.nil?

    current_user.generate_password_pii_encryption_key_pair(password)
    current_user.save!
  end
end
