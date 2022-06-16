module KeyRotator
  class HmacFingerprinter
    def rotate(user:, pii_attributes: nil, profile: nil)
      User.transaction do
        rotate_email_fingerprints(user)
        if pii_attributes
          profile ||= user.active_profile
          rotate_pii_fingerprints(profile, pii_attributes)
        end
      end
    end

    private

    # rubocop:disable Rails/SkipsModelValidations
    def rotate_pii_fingerprints(profile, pii_attributes)
      ssn_fingerprint = Pii::Fingerprinter.fingerprint(pii_attributes.ssn.to_s)

      columns_to_update = {
        ssn_signature: ssn_fingerprint,
      }

      if (compound_pii = Profile.build_compound_pii(pii_attributes))
        compound_pii_fingerprint = Pii::Fingerprinter.fingerprint(compound_pii)
        columns_to_update[:name_zip_birth_year_signature] = compound_pii_fingerprint
      end

      profile.update_columns(columns_to_update)
    end

    def rotate_email_fingerprints(user)
      user.email_addresses.each do |email_address|
        ee = EncryptedAttribute.new_from_decrypted(email_address.email)
        email_address.update_columns(email_fingerprint: ee.fingerprint)
      end
    end
    # rubocop:enable Rails/SkipsModelValidations
  end
end
