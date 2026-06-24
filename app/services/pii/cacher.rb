# frozen_string_literal: true

module Pii
  class Cacher
    attr_reader :user, :user_session, :analytics

    def initialize(user, user_session, analytics: nil)
      @user = user
      @user_session = user_session
      @analytics = analytics
    end

    def save(user_password, profile = user.active_profile)
      decrypted_pii = profile.decrypt_pii(user_password) if profile
      correct_passport_source_check(profile) if profile
      save_decrypted_pii(decrypted_pii, profile.id) if decrypted_pii
      rotate_fingerprints_if_stale(profile, decrypted_pii)
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

    # When initially enabled, proofing against a passport recorded the source_check incorrectly.
    # This was fixed in https://github.com/18F/identity-idp/pull/13039.
    # Presently we only have one valid source to verify a passport, so we can force the correction.
    def correct_passport_source_check(profile)
      # The fix was deployed in April 2026 - only correct profiles created before May 1, 2026
      return if profile.created_at > DateTime.new(2026, 5, 1)

      proofing_components = profile.proofing_components
      if proofing_components.present? &&
         proofing_components['document_type'] == 'passport' &&
         proofing_components['source_check'] != 'dos:passport'
        proofing_components['source_check'] = 'dos:passport'
        profile.proofing_components = proofing_components
        profile.save!
      end
    end

    def rotate_fingerprints_if_stale(profile, pii)
      return unless profile.present? && pii.present?
      pii_copy = pii_with_normalized_ssn(pii)

      if stale_fingerprints?(profile, pii_copy)
        analytics&.fingerprints_rotated
        KeyRotator::HmacFingerprinter.new.rotate(
          user: user,
          profile: profile,
          pii_attributes: pii_copy,
        )
      end
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

    def pii_with_normalized_ssn(pii)
      pii_copy = pii.dup
      pii_copy.ssn = SsnFormatter.normalize(pii_copy.ssn)
      pii_copy
    end
  end
end
