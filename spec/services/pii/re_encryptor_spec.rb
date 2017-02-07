require 'rails_helper'

describe Pii::ReEncryptor do
  describe '#perform' do
    it 're-encrypts PII using new code' do
      profile = create(:profile, :active, :verified, pii: { ssn: '1234' })
      user = profile.user
      user_session = {
        decrypted_pii: { ssn: '1234' }.to_json,
      }

      pii_attributes = Pii::Attributes.new
      pii_attributes[:ssn] = '1234'

      expect(user.active_profile).to receive(:encrypt_recovery_pii).
        with(pii_attributes).and_call_original
      expect(user.active_profile).to receive(:save!).and_call_original

      Pii::ReEncryptor.new(user: user, user_session: user_session).perform
    end

    it 're-encrypts PII when supplied with raw PII and explicit profile' do
      profile = create(:profile, :active, :verified, pii: { ssn: '1234' })
      pii_attributes = Pii::Attributes.new_from_hash(ssn: '1234')

      expect(profile).to receive(:encrypt_recovery_pii).
        with(pii_attributes).and_call_original
      expect(profile).to receive(:save!).and_call_original

      Pii::ReEncryptor.new(profile: profile, pii: pii_attributes).perform
    end
  end
end
