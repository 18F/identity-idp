module KeyRotator
  class HmacFingerprinter
    def rotate(user:, pii_attributes: nil, profile: nil)
      User.transaction do
        rotate_email_fingerprint(user)
        rotate_email_fingerprints(user)
        if pii_attributes
          profile ||= user.active_profile
          rotate_ssn_signature(profile, pii_attributes)
        end
      end
    end

    private

    # rubocop:disable Rails/SkipsModelValidations
    def rotate_email_fingerprint(user)
      ee = EncryptedAttribute.new_from_decrypted(user.email)
      user.update_columns(email_fingerprint: ee.fingerprint)
    end

    def rotate_ssn_signature(profile, pii_attributes)
      signature = Pii::Fingerprinter.fingerprint(pii_attributes.ssn.to_s)
      profile.update_columns(ssn_signature: signature)
    end

    def rotate_email_fingerprints(user)
      email_address = user.email_address
      ee = EncryptedAttribute.new_from_decrypted(email_address.email)
      email_address.update_columns(email_fingerprint: ee.fingerprint)
    end
    # rubocop:enable Rails/SkipsModelValidations
  end
end
