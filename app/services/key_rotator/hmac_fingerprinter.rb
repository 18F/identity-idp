module KeyRotator
  class HmacFingerprinter
    def rotate(user:, pii_attributes: nil, profile: nil)
      User.transaction do
        rotate_email_fingerprint(user)
        if pii_attributes
          profile ||= user.active_profile
          rotate_ssn_signature(profile, pii_attributes)
        end
      end
    end

    private

    def rotate_email_fingerprint(user)
      ee = EncryptedEmail.new_from_email(user.email)
      user.update_columns(email_fingerprint: ee.fingerprint)
    end

    def rotate_ssn_signature(profile, pii_attributes)
      signature = Pii::Fingerprinter.fingerprint(pii_attributes.ssn.to_s)
      profile.update_columns(ssn_signature: signature)
    end
  end
end
