require 'rails_helper'

RSpec.describe VerifyPasswordForm, type: :model do
  describe '#submit' do
    context 'when the form is valid' do
      it 'is successful' do
        password = 'cab123DZN456'
        user = create(:user, password:)
        pii = { ssn: '111111111' }
        profile = create(:profile, :verified, :password_reset, user:, pii:)

        form = VerifyPasswordForm.new(
          user:, password:,
          decrypted_pii: Pii::Attributes.new_from_hash(pii)
        )

        expect(profile.reload.active?).to eq false

        result = form.submit

        expect(profile.reload.active?).to eq true
        expect(result.success?).to eq true
      end
    end

    context 'when the password is invalid' do
      it 'returns errors' do
        password = 'cab123DZN456'
        user = create(:user, password:)
        pii = { ssn: '111111111' }
        profile = create(:profile, :verified, :password_reset, user:, pii:)

        form = VerifyPasswordForm.new(
          user:, password: "#{password}a",
          decrypted_pii: Pii::Attributes.new_from_hash(pii)
        )

        expect(profile.reload.active?).to eq false

        result = form.submit

        expect(profile.reload.active?).to eq false
        expect(result.success?).to eq false
        expect(result.errors[:password]).to eq [t('errors.messages.password_incorrect')]
      end
    end
  end
end
