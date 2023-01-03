require 'rails_helper'

describe PasswordResetEmailForm do
  subject { PasswordResetEmailForm.new(' Test@example.com ') }

  it_behaves_like 'email validation'
  it_behaves_like 'email normalization', ' Test@example.com '

  describe '#submit' do
    context 'when email is valid and user exists' do
      it 'returns hash with properties about the event and the user' do
        user = create(:user, :signed_up, email: 'test1@test.com')
        subject = PasswordResetEmailForm.new('Test1@test.com')

        expect(subject.submit.to_h).to eq(
          success: true,
          errors: {},
          user_id: user.uuid,
          confirmed: true,
          active_profile: false,
        )
        expect(subject).to respond_to(:resend)
      end
    end

    context 'when email is valid and user does not exist' do
      it 'returns hash with properties about the event and the nonexistent user' do
        expect(subject.submit.to_h).to eq(
          success: true,
          errors: {},
          user_id: 'nonexistent-uuid',
          confirmed: false,
          active_profile: false,
        )
      end
    end

    context 'when email is invalid' do
      it 'returns hash with properties about the event and the nonexistent user' do
        subject = PasswordResetEmailForm.new('invalid')

        errors = { email: [t('valid_email.validations.email.invalid')] }

        expect(subject.submit.to_h).to include(
          success: false,
          errors: errors,
          error_details: hash_including(*errors.keys),
          user_id: 'nonexistent-uuid',
          confirmed: false,
          active_profile: false,
        )
      end

      it 'returns false and adds errors to the form object when domain is invalid' do
        subject = PasswordResetEmailForm.new('test@çà.com')
        errors = { email: [t('valid_email.validations.email.invalid')] }

        expect(subject.submit.to_h).to include(
          success: false,
          errors: errors,
          error_details: hash_including(*errors.keys),
          user_id: 'nonexistent-uuid',
          confirmed: false,
          active_profile: false,
        )
      end
    end
  end
end
