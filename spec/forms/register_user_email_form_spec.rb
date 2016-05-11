require 'rails_helper'

describe RegisterUserEmailForm do
  subject { RegisterUserEmailForm.new }

  describe 'email validation' do
    it 'uses the valid_email gem with mx and ban_disposable options' do
      email_validator = subject._validators.values.flatten.first

      expect(email_validator.class).to eq EmailValidator
      expect(email_validator.options).
        to eq(mx: true, ban_disposable_email: true)
    end
  end

  describe 'email uniqueness' do
    context 'when email is already taken' do
      it 'is not valid' do
        second_user = create(:user, :signed_up, email: 'taken@gmail.com')

        subject.user.email = second_user.email
        subject.valid?

        expect(subject.errors[:email]).to eq [t('errors.messages.taken')]
      end
    end

    context 'when email is not already taken' do
      it 'is valid' do
        subject.user.email = 'not_taken@gmail.com'

        expect(subject.valid?).to be true
      end
    end

    context 'when email is nil' do
      it 'does not add already taken errors' do
        subject.user.email = nil
        subject.valid?

        expect(subject.errors[:email]).
          to eq [t('valid_email.validations.email.invalid')]
      end
    end
  end
end
