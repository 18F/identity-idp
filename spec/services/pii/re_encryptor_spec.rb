require 'rails_helper'

RSpec.describe Pii::ReEncryptor do
  describe '#perform' do
    let(:active_ssn) { '1234' }
    let(:active_pii) { { ssn: active_ssn } }

    let(:pending_ssn) { '5678' }
    let(:pending_pii) { { ssn: pending_ssn } }

    let(:user) { create(:user) }
    let(:user_session) { {}.with_indifferent_access }
    let(:pii_cacher) { Pii::Cacher.new(user, user_session) }
    let(:re_encryptor) { Pii::ReEncryptor.new(user: user, user_session: user_session) }

    context 'when the user has an active profile and a pending profile' do
      let(:expected_pii) do
        expected_pii = Pii::Attributes.new
        expected_pii[:ssn] = active_ssn
        expected_pii
      end

      it 're-encrypts PII onto the active profile using new code' do
        active_profile = create(:profile, :active, :verified, pii: active_pii, user: user)
        # creating a pending profile to make sure pending profiles are ignored when an active one is present
        create(:profile, :verify_by_mail_pending, pii: pending_pii, user: user)

        pii_cacher.save_decrypted_pii(active_pii, active_profile.id)

        re_encryptor.perform
        personal_key = user.active_profile.personal_key
        recovered_pii = Profile.find(user.active_profile.id).recover_pii(
          PersonalKeyGenerator.new(user).normalize(personal_key),
        )

        expect(recovered_pii).to eq(expected_pii)
      end
    end

    context 'when the user has a pending profile, but no active profile' do
      let(:expected_pii) do
        expected_pii = Pii::Attributes.new
        expected_pii[:ssn] = pending_ssn
        expected_pii
      end

      it 're-encrypts PII onto the pending profile using new code' do
        pending_profile = create(:profile, :verify_by_mail_pending, pii: pending_pii, user: user)
        pii_cacher.save_decrypted_pii(pending_pii, pending_profile.id)

        re_encryptor.perform
        personal_key = user.pending_profile.personal_key
o        recovered_pii = Profile.find(pending_profile.id).recover_pii(
          PersonalKeyGenerator.new(user).normalize(personal_key),
        )

        expect(recovered_pii).to eq(expected_pii)
      end
    end
  end
end
