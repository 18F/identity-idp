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
      decrypted_pii = profile.decrypt_pii(user_password) if profile
      save_decrypted_pii_json(decrypted_pii.to_json) if decrypted_pii
      rotate_fingerprints(profile) if stale_fingerprints?(profile)
      rotate_encrypted_attributes if stale_attributes?
      user_session[:decrypted_pii]
    end

    def save_decrypted_pii_json(decrypted_pii_json)
      user_session[:decrypted_pii] = decrypted_pii_json
      nil
    end

    def fetch
      pii_string = fetch_string
      return nil unless pii_string

      Pii::Attributes.new_from_json(pii_string)
    end

    # Between requests, the decrypted PII bundle is encrypted with KMS and moved to the
    # 'encrypted_pii' key by the SessionEncryptor.
    #
    # The PII is decrypted on-demand by this method and moved into the 'decrypted_pii' key.
    # See SessionEncryptor#kms_encrypt_pii! for more detail.
    def fetch_string
      return unless user_session[:decrypted_pii] || user_session[:encrypted_pii]
      return user_session[:decrypted_pii] if user_session[:decrypted_pii].present?

      decrypted = SessionEncryptor.new.kms_decrypt(
        user_session[:encrypted_pii],
      )
      user_session[:decrypted_pii] = decrypted

      decrypted
    end

    def exists_in_session?
      return user_session[:decrypted_pii] || user_session[:encrypted_pii]
    end

    def delete
      user_session.delete(:decrypted_pii)
      user_session.delete(:encrypted_pii)
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
      user.email_addresses.each do |email_address|
        KeyRotator::AttributeEncryption.new(email_address).rotate
      end

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
      user.phone_configurations.any?(&:stale_encrypted_phone?) ||
        user.email_addresses.any?(&:stale_encrypted_email?)
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
