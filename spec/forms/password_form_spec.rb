require 'rails_helper'

describe PasswordForm do
  subject { PasswordForm.new(build_stubbed(:user)) }

  it_behaves_like 'password validation'

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

    context 'when the password is not strong enough' do
      it 'returns false and adds user errors to the form errors' do
        allow(Figaro.env).to receive(:password_strength_enabled).and_return('true')

        user = build_stubbed(:user, email: 'custom@benevolent.com')

        form = PasswordForm.new(user)

        passwords = [user.email, 'custom!@', 'benevolent', 'custom benevolent comcast', APP_NAME]

        passwords.each do |password|
          expect(form.submit(password: password)).
            to eq false

          expect(form.errors.full_messages.first).to match 'not strong enough'
        end
      end
    end
  end
end
