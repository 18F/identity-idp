require 'rails_helper'

describe PasswordForm, type: :model do
  subject { PasswordForm.new(build_stubbed(:user)) }

  it_behaves_like 'password validation'
  it_behaves_like 'strong password', 'PasswordForm'

  describe '#submit' do
    context 'when the form is valid' do
      it 'returns true' do
        user = build_stubbed(:user)

        form = PasswordForm.new(user)
        password = 'valid password'
        extra = {
          user_id: user.uuid,
          request_id_present: false,
        }

        result = form.submit(password: password)

        expect(result.success?).to eq true
        expect(result.extra).to eq extra
      end
    end

    context 'when the form is invalid' do
      it 'returns false' do
        user = build_stubbed(:user, uuid: '123')

        form = PasswordForm.new(user)
        password = 'invalid'
        errors = {
          password: ["is too short (minimum is #{Devise.password_length.first} characters)"],
        }
        extra = {
          user_id: '123',
          request_id_present: false,
        }

        result = form.submit(password: password)
        expect(result.success?).to eq false
        expect(result.errors).to eq errors
        expect(result.extra).to eq extra
      end
    end

    context 'when the request_id is passed in the params' do
      it 'tracks that it is present' do
        user = build_stubbed(:user)
        form = PasswordForm.new(user)
        password = 'valid password'
        extra = {
          user_id: user.uuid,
          request_id_present: true,
        }

        result = form.submit(password: password, request_id: 'foo')
        expect(result.success?).to eq true
        expect(result.extra).to eq extra
      end
    end

    context 'when the request_id is not properly encoded' do
      it 'does not throw an exception' do
        user = build_stubbed(:user)
        form = PasswordForm.new(user)
        password = 'valid password'
        extra = {
          user_id: user.uuid,
          request_id_present: true,
        }
        result = form.submit(password: password, request_id: "\xFFbar\xF8")
        expect(result.success?).to eq true
        expect(result.extra).to eq extra
      end
    end
  end
end
