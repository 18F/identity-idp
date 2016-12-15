require 'rails_helper'

describe KeyRotator::HmacFingerprinter do
  describe '#rotate' do
    it 'changes email and ssn fingerprints' do
      rotator = described_class.new
      profile = create(:profile, :active, :verified, pii: { ssn: '1234' })
      user = profile.user
      user_access_key = user.user_access_key
      pii_attributes = profile.decrypt_pii(user_access_key)

      old_ssn_signature = profile.ssn_signature
      old_email_fingerprint = user.email_fingerprint

      old_hmac_key = Figaro.env.hmac_fingerprinter_key
      allow(Figaro.env).to receive(:hmac_fingerprinter_key_queue).and_return(
        "[\"#{old_hmac_key}\"]"
      )
      allow(Figaro.env).to receive(:hmac_fingerprinter_key).and_return('a-new-key')

      rotator.rotate(user, pii_attributes)

      expect(user.active_profile.ssn_signature).to_not eq old_ssn_signature
      expect(user.email_fingerprint).to_not eq old_email_fingerprint
    end
  end
end
