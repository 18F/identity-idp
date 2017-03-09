require 'rails_helper'

describe ResendEmailConfirmationForm do
  subject { ResendEmailConfirmationForm.new(' Test@example.com ') }

  it_behaves_like 'email validation'
  it_behaves_like 'email normalization', ' Test@example.com '

  describe '#submit' do
    context 'when email is valid and user exists' do
      it 'returns hash with properties about the event and the user' do
        user = build(:user, :signed_up)
        subject = ResendEmailConfirmationForm.new(user.email)

        extra = {
          user_id: user.uuid,
          confirmed: true,
        }
        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(subject.submit).to eq result
        expect(subject.email).to eq user.email
      end
    end

    context 'when email is valid and user does not exist' do
      it 'returns hash with properties about the event and the nonexistent user' do
        extra = {
          user_id: 'nonexistent-uuid',
          confirmed: false,
        }
        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(subject.submit).to eq result
      end
    end

    context 'when email is invalid' do
      it 'returns hash with properties about the event and the nonexistent user' do
        subject = ResendEmailConfirmationForm.new('invalid')

        extra = {
          user_id: 'nonexistent-uuid',
          confirmed: false,
        }
        errors = { email: [t('valid_email.validations.email.invalid')] }
        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: false, errors: errors, extra: extra).and_return(result)
        expect(subject.submit).to eq result
      end
    end
  end
end
