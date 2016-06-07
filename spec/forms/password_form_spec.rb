require 'rails_helper'

describe PasswordForm do
  subject { PasswordForm.new(build_stubbed(:user)) }

  it do
    is_expected.to validate_confirmation_of(:password)
  end

  it do
    is_expected.to validate_length_of(:password).
      is_at_least(Devise.password_length.first)
  end

  it do
    is_expected.to validate_length_of(:password).
      is_at_most(Devise.password_length.last)
  end

  it do
    is_expected.to allow_value('ValidPassword1!').for(:password)
  end

  it do
    is_expected.to allow_value('ValidPassword1').for(:password)
  end

  it do
    is_expected.to allow_value('validpassword1!').for(:password)
  end

  it do
    is_expected.to allow_value('VALIDPASSWORD1!').for(:password)
  end

  it do
    is_expected.to allow_value('ValidPASSWORD!').for(:password)
  end

  it do
    is_expected.to allow_value('bear bull bat baboon').for(:password)
  end

  it "is initialized with the user's reset_password_token" do
    user = build_stubbed(:user, reset_password_token: 'foo')

    form = PasswordForm.new(user)

    expect(form.reset_password_token).to eq 'foo'
  end

  describe '#submit' do
    context 'when the form is valid but the user is not valid' do
      it 'returns false' do
        user = build_stubbed(:user)
        user.errors.add(:reset_password_token, 'expired')

        form = PasswordForm.new(user)

        password = 'valid password'

        expect(form.submit(password: password)).
          to eq false
      end
    end

    context 'when the form is invalid' do
      it 'returns false' do
        user = build_stubbed(:user)

        form = PasswordForm.new(user)

        password = 'invalid'

        expect(form.submit(password: password)).
          to eq false
      end
    end

    context 'when both the form and user are valid' do
      it 'sets the user password to the submitted password' do
        user = build_stubbed(:user)

        form = PasswordForm.new(user)

        password = 'valid password'

        form.submit(password: password)

        expect(user.password).to eq password
      end
    end
  end
end
