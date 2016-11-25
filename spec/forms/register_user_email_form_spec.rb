require 'rails_helper'

describe RegisterUserEmailForm do
  subject { RegisterUserEmailForm.new }

  it_behaves_like 'email validation'

  describe '#submit' do
    context 'when email is already taken' do
      it 'sets success to true to prevent revealing account existence' do
        existing_user = create(:user, :signed_up, email: 'taken@gmail.com')

        result = {
          success: true,
          errors: [],
          email_already_exists: true,
          user_id: existing_user.uuid
        }

        mailer = instance_double(ActionMailer::MessageDelivery)
        expect(UserMailer).to receive(:signup_with_your_email).
          with(existing_user.email).and_return(mailer)
        expect(mailer).to receive(:deliver_later)

        expect(subject.submit(email: 'TAKEN@gmail.com')).to eq result

        expect(subject.email).to eq 'taken@gmail.com'
      end
    end

    context 'when email is already taken and existing user is unconfirmed' do
      it 'sends confirmation instructions to existing user' do
        user = instance_double(User, email: 'existing@test.com', confirmed?: false, uuid: '123')
        allow(User).to receive(:find_with_email).with(user.email).and_return(user)

        expect(user).to receive(:send_confirmation_instructions)

        result = {
          success: true,
          errors: [],
          email_already_exists: true,
          user_id: '123'
        }

        expect(subject.submit(email: user.email)).to eq result
      end
    end

    context 'when email is not already taken' do
      it 'is valid' do
        result = subject.submit(email: 'not_taken@gmail.com')

        result_hash = {
          success: true,
          errors: [],
          email_already_exists: false,
          user_id: User.find_with_email('not_taken@gmail.com').uuid
        }

        expect(result).to eq result_hash
      end
    end

    context 'when email is invalid' do
      it 'returns false and adds errors to the form object' do
        result = {
          success: false,
          errors: [t('valid_email.validations.email.invalid')],
          email_already_exists: false,
          user_id: nil
        }

        expect(subject.submit(email: 'invalid_email')).to eq result
      end
    end
  end
end
