# PII is stored encrypted in the database using the user's passphrase.
# Since we need to access the PII during the entire user session,
# but we only have the passphrase at initial log in,
# we use the passphrase to decrypt the PII at log in,
# and store the PII, de-crypted, in the encrypted session.
#
module Pii
  class Cacher
    def initialize(user, user_session)
      @user = user
      @user_session = user_session
    end

    def save(user_access_key, profile = user.active_profile)
      return unless profile
      user_session[:decrypted_pii] = profile.decrypt_pii(user_access_key).to_json
    end

    def fetch
      decrypted_pii = user_session[:decrypted_pii]
      return unless decrypted_pii
      Pii::Attributes.new_from_json(decrypted_pii)
    end

    private

    attr_reader :user, :user_session
  end
end
