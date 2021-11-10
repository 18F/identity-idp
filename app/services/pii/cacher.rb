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
      return unless profile
      decrypted_pii = profile.decrypt_pii(user_password).to_json if profile
      # user_session[:decrypted_pii] = decrypted_pii
      redis_pii = DecryptedPii.new(
        id: SecureRandom.uuid,
        pii: decrypted_pii,
      )
      EncryptedRedisStructStorage.store(redis_pii, expires_in: 1_000)
      user_session[:pii_id] = redis_pii.id
      rotate_fingerprints(profile) if stale_fingerprints?(profile)
      rotate_encrypted_attributes if stale_attributes?
      decrypted_pii
    end

    def fetch
      id = user_session[:pii_id]
      return unless id
      redis_pii = EncryptedRedisStructStorage.load(id, type: DecryptedPii)
      decrypted_pii = redis_pii.pii
      # decrypted_pii = user_session[:decrypted_pii]
      return unless decrypted_pii
      Pii::Attributes.new_from_json(decrypted_pii)
    end

    private

    attr_reader :user, :user_session

    def rotate_fingerprints(profile)
      KeyRotator::HmacFingerprinter.new.rotate(
        user: user,
        profile: profile,
        pii_attributes: fetch,
      )
    end

    def rotate_encrypted_attributes
      KeyRotator::AttributeEncryption.new(user).rotate
      user.phone_configurations.each do |phone_configuration|
        KeyRotator::AttributeEncryption.new(phone_configuration).rotate
      end
    end

    def stale_fingerprints?(profile)
      stale_email_fingerprint? ||
        stale_ssn_signature?(profile) ||
        stale_compound_pii_signature?(profile)
    end

    def stale_email_fingerprint?
      user.email_addresses.any?(&:stale_email_fingerprint?)
    end

    def stale_attributes?
      user.phone_configurations.any?(&:stale_encrypted_phone?) || user.stale_encrypted_email?
    end

    def stale_ssn_signature?(profile)
      return false unless profile
      decrypted_pii = fetch
      return false unless decrypted_pii
      Pii::Fingerprinter.stale?(decrypted_pii.ssn, profile.ssn_signature)
    end

    def stale_compound_pii_signature?(profile)
      return false unless profile
      decrypted_pii = fetch
      return false unless decrypted_pii
      compound_pii = Profile.build_compound_pii(decrypted_pii)
      return false unless compound_pii
      Pii::Fingerprinter.stale?(compound_pii, profile.name_zip_birth_year_signature)
    end
  end
end
