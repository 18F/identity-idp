# PII is stored encrypted in the database using the user's passphrase.
# Since we need to access the PII during the entire user session,
# but we only have the passphrase at initial log in,
# we use the passphrase to decrypt the PII at log in,
# and then re-encrypt it using server passphrase within the user
# session for access.
#
module Pii
  class Cacher
    def initialize(user, user_session)
      @user = user
      @user_session = user_session
    end

    def save(password, profile = user.active_profile)
      return unless profile
      user_session[:encrypted_pii] = re_encrypt(profile, password)
    end

    def fetch
      encrypted_pii = user_session[:encrypted_pii]
      return unless encrypted_pii
      decrypted_pii = encryptor.decrypt(encrypted_pii)
      Pii::Attributes.new_from_json(decrypted_pii)
    end

    private

    attr_reader :user, :user_session

    def encryptor
      Pii::Encryptor.new
    end

    def re_encrypt(profile, password)
      decrypted_pii = profile.decrypt_pii(password)
      pii_json = decrypted_pii.to_json
      encryptor.encrypt(pii_json)
    end
  end
end
