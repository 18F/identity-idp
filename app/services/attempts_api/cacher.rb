# frozen_string_literal: true

module AttemptsApi
  class Cacher
    attr_reader :user, :user_session

    def initialize(user, user_session)
      @user = user
      @user_session = user_session
    end

    def save(password:)
      decrypted_events = user.active_profile.decrypt_user_proofing_events(password:)

      kms_encrypted_events = SessionEncryptor.new.kms_encrypt(decrypted_events)
      user_session[:encrypted_proofing_events] = kms_encrypted_events
    end

    def fetch
      return if user_session[:encrypted_proofing_events].blank?

      encrypted_events = user_session[:encrypted_proofing_events]
      JSON.parse(SessionEncryptor.new.kms_decrypt(encrypted_events))
    end
  end
end
