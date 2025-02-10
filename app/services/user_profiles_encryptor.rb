# frozen_string_literal: true

class UserProfilesEncryptor
  class MissingPiiError < StandardError
  end

  attr_reader :personal_key

  def initialize(user:, user_session:, password:)
    @user = user
    @user_session = user_session
    @password = password
  end

  def encrypt
    if user.active_profile.present?
      encrypt_pii_for_profile(user.active_profile)
    end

    if user.pending_profile.present?
      begin
        encrypt_pii_for_profile(user.pending_profile)
      rescue MissingPiiError
        user.pending_profile.deactivate(:encryption_error)
      end
    end
  end

  private

  attr_reader :user, :password, :user_session

  def encrypt_pii_for_profile(profile)
    pii_cache = Pii::Cacher.new(user, user_session)
    pii = pii_cache.fetch(profile.id)
    raise MissingPiiError unless pii

    @personal_key = profile.encrypt_pii(pii, password)
    profile.save!
  end
end
