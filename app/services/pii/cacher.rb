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

    def save(user_password, profile = user.active_profile)
      user_session[:decrypted_pii] = profile.decrypt_pii(user_password).to_json if profile
      rotate_fingerprints(profile) if stale_fingerprints?(profile)
      rotate_encrypted_attributes if stale_attributes?
      user_session[:decrypted_pii]
    end

    def fetch
      decrypted_pii = user_session[:decrypted_pii]
      return unless decrypted_pii
      Pii::Attributes.new_from_json(decrypted_pii)
    end

    private

    attr_reader :user, :user_session

    def rotate_fingerprints(profile)
      KeyRotator::HmacFingerprinter.new.rotate(
        user: user,
        profile: profile,
        pii_attributes: fetch
      )
    end

    def rotate_encrypted_attributes
      KeyRotator::AttributeEncryption.new(user).rotate
    end

    def stale_fingerprints?(profile)
      stale_email_fingerprint? || stale_ssn_signature?(profile)
    end

    def stale_email_fingerprint?
      Pii::Fingerprinter.stale?(user.email, user.email_fingerprint)
    end

    def stale_attributes?
      user.stale_encrypted_phone? || user.stale_encrypted_email? ||
        user.stale_encrypted_otp_secret_key?
    end

    def stale_ssn_signature?(profile)
      return false unless profile
      decrypted_pii = fetch
      return false unless decrypted_pii
      Pii::Fingerprinter.stale?(decrypted_pii.ssn, profile.ssn_signature)
    end
  end
end
