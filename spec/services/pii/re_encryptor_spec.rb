require 'rails_helper'

RSpec.describe Pii::ReEncryptor do
  let(:expected_pii_attributes) do
    pii_attributes = Pii::Attributes.new
    pii_attributes[:ssn] = ssn
    pii_attributes
  end

  let(:pii) { { ssn: ssn } }
  let(:pii_cacher) { Pii::Cacher.new(user, user_session) }
  let(:ssn) { '1234' }
  let(:user) { profile.user }
  let(:user_session) { {}.with_indifferent_access }

  before do
    allow(Pii::Cacher).to receive(:new).and_return(pii_cacher)
    allow(pii_cacher).to receive(:fetch).and_call_original

    if user.active_profile
      allow(user.active_profile).to receive(:encrypt_recovery_pii).and_call_original
      allow(user.active_profile).to receive(:save!).and_call_original
    end

    if user.pending_profile
      allow(user.pending_profile).to receive(:encrypt_recovery_pii).and_call_original
      allow(user.pending_profile).to receive(:save!).and_call_original
    end

    Pii::ProfileCacher.new(user, user_session).save_decrypted_pii(pii, profile.id)
  end

  describe '#perform' do
    context 'when the user has an active profile' do
      let(:profile) { create(:profile, :active, :verified, pii: pii) }

      before do
        Pii::ReEncryptor.new(user: user, user_session: user_session).perform
      end

      it 'fetches the PII from the correct profile' do
        expect(pii_cacher).to have_received(:fetch).with(profile.id)
      end

      it 're-encrypts PII using new code' do
        expect(user.active_profile).to have_received(:encrypt_recovery_pii).
          with(expected_pii_attributes)
        expect(user.active_profile).to have_received(:save!)
      end
    end

    context 'when the user has a pending profile' do
      let(:profile) { create(:profile, :verify_by_mail_pending, pii: pii) }

      before do
        Pii::ReEncryptor.new(user: user, user_session: user_session).perform
      end

      it 'fetches the PII from the correct profile' do
        expect(pii_cacher).to have_received(:fetch).with(profile.id)
      end

      it 're-encrypts PII using new code' do
        expect(user.pending_profile).to have_received(:encrypt_recovery_pii).
          with(expected_pii_attributes)
        expect(user.pending_profile).to have_received(:save!)
      end
    end
  end
end
