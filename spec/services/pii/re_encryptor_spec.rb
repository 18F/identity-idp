require 'rails_helper'

RSpec.describe Pii::ReEncryptor do
  describe '#perform' do
    context 'when the user has an active profile' do
      let(:active_profile) { create(:profile, :active, :verified, pii: pii) }
      let(:pii) { { ssn: ssn } }
      let(:pii_cacher) { Pii::Cacher.new(user, user_session) }
      let(:ssn) { ' 1234' }
      let(:user) { active_profile.user }
      let(:user_session) { {}.with_indifferent_access }

      let(:expected_pii_attributes) do
        pii_attributes = Pii::Attributes.new
        pii_attributes[:ssn] = ssn
        pii_attributes
      end

      before do
        Pii::ProfileCacher.new(user, user_session).save_decrypted_pii(pii, active_profile.id)

        allow(Pii::Cacher).to receive(:new).and_return(pii_cacher)
        allow(pii_cacher).to receive(:fetch).and_call_original
        allow(user.active_profile).to receive(:encrypt_recovery_pii).and_call_original
        allow(user.active_profile).to receive(:save!).and_call_original

        Pii::ReEncryptor.new(user: user, user_session: user_session).perform
      end

      it 'fetches the PII from the correct profile' do
        expect(pii_cacher).to have_received(:fetch).with(active_profile.id)
      end

      it 're-encrypts PII using new code' do
        expect(user.active_profile).to have_received(:encrypt_recovery_pii).
          with(expected_pii_attributes)
        expect(user.active_profile).to have_received(:save!)
      end
    end

    context 'when the user has a pending profile' do
      let(:pending_profile) { create(:profile, :verify_by_mail_pending, pii: pii) }
      let(:pii) { { ssn: ssn } }
      let(:pii_cacher) { Pii::Cacher.new(user, user_session) }
      let(:ssn) { ' 1234' }
      let(:user) { pending_profile.user }
      let(:user_session) { {}.with_indifferent_access }

      let(:expected_pii_attributes) do
        pii_attributes = Pii::Attributes.new
        pii_attributes[:ssn] = ssn
        pii_attributes
      end

      before do
        Pii::ProfileCacher.new(user, user_session).save_decrypted_pii(pii, pending_profile.id)

        allow(Pii::Cacher).to receive(:new).and_return(pii_cacher)
        allow(pii_cacher).to receive(:fetch).and_call_original
        allow(user.pending_profile).to receive(:encrypt_recovery_pii).and_call_original
        allow(user.pending_profile).to receive(:save!).and_call_original

        Pii::ReEncryptor.new(user: user, user_session: user_session).perform
      end

      it 'fetches the PII from the correct profile' do
        expect(pii_cacher).to have_received(:fetch).with(pending_profile.id)
      end

      it 're-encrypts PII using new code' do
        expect(user.pending_profile).to have_received(:encrypt_recovery_pii).
          with(expected_pii_attributes)
        expect(user.pending_profile).to have_received(:save!)
      end
    end
  end
end
