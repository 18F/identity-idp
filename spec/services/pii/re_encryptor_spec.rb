require 'rails_helper'

describe Pii::ReEncryptor do
  describe '#perform' do
    it 're-encrypts PII using new code' do
      profile = build_stubbed(:profile, :active, :verified, pii: { ssn: '1234' })
      user = build_stubbed(:user, profiles: [profile])
      user_session = {
        decrypted_pii: { ssn: '1234' }.to_json
      }

      pii_attributes = Pii::Attributes.new
      pii_attributes[:ssn] = '1234'

      expect(user.active_profile).to receive(:encrypt_recovery_pii).
        with(pii_attributes).and_call_original
      expect(user.active_profile).to receive(:save!).and_call_original

      Pii::ReEncryptor.new(user, user_session).perform
    end
  end
end
