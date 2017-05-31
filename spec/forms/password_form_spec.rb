require 'rails_helper'

describe PasswordForm, type: :model do
  subject { PasswordForm.new(build_stubbed(:user)) }

  it_behaves_like 'password validation'

  describe '#submit' do
    context 'when the form is valid' do
      it 'returns true' do
        user = build_stubbed(:user)

        form = PasswordForm.new(user)

        password = 'valid password'

        extra = {
          user_id: user.uuid,
        }

        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(form.submit(password: password)).to eq result
      end
    end

    context 'when the form is invalid' do
      it 'returns false' do
        user = build_stubbed(:user, uuid: '123')

        form = PasswordForm.new(user)

        password = 'invalid'

        errors = {
          password: ['is too short (minimum is 8 characters)'],
        }

        extra = {
          user_id: '123',
        }

        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: false, errors: errors, extra: extra).and_return(result)
        expect(form.submit(password: password)).to eq result
      end
    end

    context 'when the password is not strong enough' do
      it 'returns false and adds user errors to the form errors' do
        allow(Figaro.env).to receive(:password_strength_enabled).and_return('true')

        user = build_stubbed(:user, email: 'custom@benevolent.com', uuid: '123')

        form = PasswordForm.new(user)

        passwords = ['custom!@', 'benevolent', 'custom benevolent comcast']

        errors = {
          password: ['Your password is not strong enough.' \
            ' This is similar to a commonly used password.' \
            ' Add another word or two.' \
            ' Uncommon words are better.'],
        }

        passwords.each do |password|
          extra = {
            user_id: '123',
          }
          result = instance_double(FormResponse)

          expect(FormResponse).to receive(:new).
            with(success: false, errors: errors, extra: extra).and_return(result)
          expect(form.submit(password: password)).to eq result
        end
      end
    end
  end
end
