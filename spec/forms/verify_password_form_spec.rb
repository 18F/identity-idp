require 'rails_helper'

describe VerifyPasswordForm, type: :model do
  describe '#submit' do
    context 'when the form is valid' do
      it 'is successful' do
        password = 'cab123DZN456'
        user = create(:user, password: password)
        pii = { ssn: '111111111' }
        create(:profile, :password_reset, user: user, pii: pii)

        form = VerifyPasswordForm.new(
          user: user, password: password,
          decrypted_pii: Pii::Attributes.new_from_hash(pii)
        )

        result = form.submit

        expect(result.success?).to eq true
      end
    end

    context 'when the password is invalid' do
      it 'returns errors' do
        password = 'cab123DZN456'
        user = create(:user, password: password)
        pii = { ssn: '111111111' }
        create(:profile, :password_reset, user: user, pii: pii)

        form = VerifyPasswordForm.new(
          user: user, password: "#{password}a",
          decrypted_pii: Pii::Attributes.new_from_hash(pii)
        )

        result = form.submit

        expect(result.success?).to eq false
        expect(result.errors[:password]).to eq [t('errors.messages.password_incorrect')]
      end
    end
  end
end
