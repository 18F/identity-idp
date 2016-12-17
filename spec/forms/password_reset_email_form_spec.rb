require 'rails_helper'

describe PasswordResetEmailForm do
  subject { PasswordResetEmailForm.new('test@example.com') }

  it_behaves_like 'email validation'

  describe '#submit' do
    context 'when email is valid and user exists' do
      it 'returns hash with properties about the event and the user' do
        user = build(:user, :signed_up)
        subject = PasswordResetEmailForm.new(user.email)

        result = {
          success: true,
          errors: [],
          user_id: user.uuid,
          role: user.role,
          confirmed: true
        }

        expect(subject.submit).to eq result
        expect(subject.email).to eq user.email
        expect(subject).to respond_to(:resend)
      end
    end

    context 'when email is valid and user does not exist' do
      it 'returns hash with properties about the event and the nonexistent user' do
        result = {
          success: true,
          errors: [],
          user_id: 'nonexistent-uuid',
          role: 'nonexistent',
          confirmed: false
        }

        expect(subject.submit).to eq result
      end
    end

    context 'when email is invalid' do
      it 'returns hash with properties about the event and the nonexistent user' do
        subject = PasswordResetEmailForm.new('invalid')

        result = {
          success: false,
          errors: [t('valid_email.validations.email.invalid')],
          user_id: 'nonexistent-uuid',
          role: 'nonexistent',
          confirmed: false
        }

        expect(subject.submit).to eq result
      end
    end
  end
end
