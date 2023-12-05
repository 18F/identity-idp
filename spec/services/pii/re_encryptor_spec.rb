require 'rails_helper'

RSpec.describe Pii::ReEncryptor do
  describe '#perform' do
    let(:active_profile) { create(:profile, :active, :verified, pii: pii) }
    let(:pii) { { ssn: ssn } }
    let(:ssn) { ' 1234' }
    let(:user) { active_profile.user }
    let(:user_session) { { decrypted_pii: pii.to_json } }

    let(:expected_pii_attributes) do
      pii_attributes = Pii::Attributes.new
      pii_attributes[:ssn] = ssn
      pii_attributes
    end

    before do
      allow(user.active_profile).to receive(:encrypt_recovery_pii).and_call_original
      allow(user.active_profile).to receive(:save!).and_call_original

      Pii::ReEncryptor.new(user: user, user_session: user_session).perform
    end

    it 're-encrypts PII using new code' do
      expect(user.active_profile).to have_received(:encrypt_recovery_pii).
        with(expected_pii_attributes)
      expect(user.active_profile).to have_received(:save!)
    end
  end
end
