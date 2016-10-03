module Pii
  class Cacher
    def initialize(user, user_session)
      @user = user
      @user_session = user_session
    end

    def save(password, profile = user.active_profile)
      return unless profile
      decrypted_pii = profile.decrypt_pii(password)
      pii_json = decrypted_pii.to_json
      encrypted_pii = encryptor.encrypt_with_key(pii_json, key_maker.server_key)
      user_session[:encrypted_pii] = encrypted_pii
    end

    def fetch
      encrypted_pii = user_session[:encrypted_pii]
      return unless encrypted_pii
      decrypted_pii = encryptor.decrypt_with_key(encrypted_pii, key_maker.server_key)
      Profile.inflate_pii_json(decrypted_pii)
    end

    private

    attr_reader :user, :user_session

    def key_maker
      Pii::KeyMaker.new
    end

    def encryptor
      Pii::Encryptor.new
    end
  end
end
