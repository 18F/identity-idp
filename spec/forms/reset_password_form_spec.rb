require 'rails_helper'

describe ResetPasswordForm, type: :model do
  subject { ResetPasswordForm.new(build_stubbed(:user, uuid: '123')) }

  it_behaves_like 'password validation'

  describe '#submit' do
    context 'when the password is valid but the token has expired' do
      it 'returns a hash with errors' do
        user = build_stubbed(:user, uuid: '123')
        allow(user).to receive(:reset_password_period_valid?).and_return(false)

        form = ResetPasswordForm.new(user)

        password = 'valid password'

        errors = { reset_password_token: ['token_expired'] }

        extra = { user_id: '123' }

        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: false, errors: errors, extra: extra).and_return(result)
        expect(form.submit(password: password)).to eq result
      end
    end

    context 'when the password is invalid and token is valid' do
      it 'returns a hash with errors' do
        user = build_stubbed(:user, uuid: '123')
        allow(user).to receive(:reset_password_period_valid?).and_return(true)

        form = ResetPasswordForm.new(user)

        password = 'invalid'

        errors = {
          password: ["is too short (minimum is #{Devise.password_length.first} characters)"],
        }

        extra = { user_id: '123' }

        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: false, errors: errors, extra: extra).and_return(result)
        expect(form.submit(password: password)).to eq result
      end
    end

    context 'when both the password and token are valid' do
      it 'sets the user password to the submitted password' do
        user = create(:user, uuid: '123')
        allow(user).to receive(:reset_password_period_valid?).and_return(true)

        form = ResetPasswordForm.new(user)
        password = 'valid password'
        extra = { user_id: '123' }
        result = instance_double(FormResponse)
        user_updater = instance_double(UpdateUser)
        allow(UpdateUser).to receive(:new).
          with(user: user, attributes: { password: password }).and_return(user_updater)

        expect(user_updater).to receive(:call)
        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(form.submit(password: password)).to eq result
      end
    end

    context 'when both the password and token are invalid' do
      it 'returns a hash with errors' do
        user = build_stubbed(:user, uuid: '123')
        allow(user).to receive(:reset_password_period_valid).and_return(false)

        form = ResetPasswordForm.new(user)

        password = 'short'

        errors = {
          password: ["is too short (minimum is #{Devise.password_length.first} characters)"],
          reset_password_token: ['token_expired'],
        }

        extra = { user_id: '123' }

        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: false, errors: errors, extra: extra).and_return(result)
        expect(form.submit(password: password)).to eq result
      end
    end

    context 'when the user does not exist in the db' do
      it 'returns a hash with errors' do
        user = User.new

        form = ResetPasswordForm.new(user)
        errors = {
          reset_password_token: ['invalid_token'],
        }

        extra = { user_id: nil }

        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: false, errors: errors, extra: extra).and_return(result)
        expect(form.submit(password: 'a good and powerful password')).to eq result
      end
    end

    it_behaves_like 'strong password', 'ResetPasswordForm'
  end
end
