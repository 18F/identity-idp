require 'rails_helper'

describe UpdateUserEmailForm do
  let(:user) { build_stubbed(:user, :signed_up) }
  subject { UpdateUserEmailForm.new(user) }

  it do
    is_expected.
      to validate_presence_of(:email).
      with_message(t('valid_email.validations.email.invalid'))
  end

  describe 'email validation' do
    it 'uses the valid_email gem with mx and ban_disposable options' do
      email_validator = subject._validators.values.flatten.
                        detect { |v| v.class == EmailValidator }

      expect(email_validator.options).
        to eq(mx: true, ban_disposable_email: true)
    end
  end

  describe 'email uniqueness' do
    context 'when email is already taken' do
      it 'is invalid' do
        second_user = build_stubbed(:user, :signed_up, email: 'taken@gmail.com')
        allow(User).to receive(:exists?).with(email: second_user.email).and_return(true)

        subject.email = second_user.email

        expect(subject.valid_form?).to be false
      end
    end

    context 'when email is not already taken' do
      it 'is valid' do
        subject.email = 'not_taken@gmail.com'

        expect(subject.valid_form?).to be true
      end
    end

    context 'when email is same as current user' do
      it 'is valid' do
        subject.email = user.email

        expect(subject.valid_form?).to be true
      end
    end

    context 'when email is nil' do
      it 'does not add already taken errors' do
        subject.email = nil

        expect(subject.valid_form?).to be false
        expect(subject.instance_variable_get(:@email_taken)).to be_nil
        expect(subject.errors[:email].uniq).
          to eq [t('valid_email.validations.email.invalid')]
      end
    end
  end
end
