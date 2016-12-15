module KeyRotator
  class HmacFingerprinter
    def rotate(user, pii_attributes)
      User.transaction do
        rotate_email_fingerprint(user)
        rotate_ssn_signature(user.active_profile, pii_attributes)
      end
    end

    private

    def rotate_email_fingerprint(user)
      ee = EncryptedEmail.new_from_email(user.email)
      user.update_columns(email_fingerprint: ee.fingerprint)
    end

    def rotate_ssn_signature(profile, pii_attributes)
      profile.update_columns(ssn_signature: Pii::Fingerprinter.fingerprint(pii_attributes.ssn))
    end
  end
end
