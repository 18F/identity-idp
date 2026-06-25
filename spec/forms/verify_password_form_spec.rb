require 'rails_helper'

RSpec.describe VerifyPasswordForm, type: :model do
  describe '#submit' do
    let(:password) { 'cab123DZN456' }
    let(:user) { create(:user, password:) }
    let(:pii) { { ssn: '111111111' } }
    let(:profile) { create(:profile, :verified, :password_reset, user:, pii:) }
    let(:decrypted_attempt_events) { nil }
    let(:form) do
      VerifyPasswordForm.new(
        user: user, password: attempted_password,
        decrypted_pii: Pii::Attributes.new_from_hash(pii),
        decrypted_attempt_events:
      )
    end

    context 'when the form is valid' do
      let(:attempted_password) { password }

      it 'is successful' do
        expect(profile.reload.active?).to eq false

        result = form.submit

        expect(profile.reload.active?).to eq true
        expect(result.to_h).to eq(success: true)
      end

      context 'when decrypted attempt events are present' do
        let(:decrypted_attempt_events) { [{ event: 'test_event' }] }

        before do
          allow(user).to receive(:password_reset_profile).and_return(profile)
        end

        it 'reencrypts the attempt events' do
          expect(profile).to receive(:reencrypt_user_proofing_events).with(
            password: attempted_password,
            attempt_events: decrypted_attempt_events,
            personal_key: String,
          )

          form.submit
        end
      end
    end

    context 'when the password is invalid' do
      let(:attempted_password) { 'wrong-password' }

      it 'returns errors' do
        expect(profile.reload.active?).to eq false

        result = form.submit

        expect(profile.reload.active?).to eq false
        expect(result.to_h).to eq(
          success: false,
          error_details: { password: { password_incorrect: true } },
        )
      end
    end
  end
end
