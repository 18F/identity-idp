module Pii
  class ProfileCacher
    attr_reader :user, :user_session

    def initialize(user, user_session)
      @user = user
      @user_session = user_session
    end

    def save(user_password, profile = user.active_profile)
      decrypted_pii = profile.decrypt_pii(user_password) if profile
      save_decrypted_pii(decrypted_pii, profile.id) if decrypted_pii
      rotate_fingerprints(profile, decrypted_pii) if stale_fingerprints?(profile, decrypted_pii)
      decrypted_pii
    end

    def save_decrypted_pii(decrypted_pii, profile_id)
      kms_encrypted_pii = SessionEncryptor.new.kms_encrypt(decrypted_pii.to_json)

      user_session[:encrypted_profiles] ||= {}
      user_session[:encrypted_profiles][profile_id.to_s] = kms_encrypted_pii
    end

    def fetch(profile_id)
      return unless user_session[:encrypted_profiles].present?

      encrypted_profile_pii = user_session[:encrypted_profiles][profile_id.to_s]
      return unless encrypted_profile_pii.present?

      decrypted_profile_pii_json = SessionEncryptor.new.kms_decrypt(encrypted_profile_pii)
      Pii::Attributes.new_from_json(decrypted_profile_pii_json)
    end

    def exists_in_session?
      user_session[:encrypted_profiles].present?
    end

    def delete
      user_session.delete(:encrypted_profiles)
    end

    private

    def rotate_fingerprints(profile, pii)
      KeyRotator::HmacFingerprinter.new.rotate(
        user: user,
        profile: profile,
        pii_attributes: pii,
      )
    end

    def stale_fingerprints?(profile, pii)
      stale_ssn_signature?(profile, pii) ||
        stale_compound_pii_signature?(profile, pii)
    end

    def stale_ssn_signature?(profile, pii)
      return false unless profile.present? && pii.present?
      Pii::Fingerprinter.stale?(pii.ssn, profile.ssn_signature)
    end

    def stale_compound_pii_signature?(profile, pii)
      return false unless profile.present? && pii.present?
      compound_pii = Profile.build_compound_pii(pii)
      return false unless compound_pii
      Pii::Fingerprinter.stale?(compound_pii, profile.name_zip_birth_year_signature)
    end
  end
end
