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

        extra = { user_id: '123', profile_deactivated: false }

        expect(form.submit(password: password).to_h).to include(
          success: false,
          errors: errors,
          error_details: hash_including(*errors.keys),
          **extra,
        )
      end
    end

    context 'when the password is invalid and token is valid' do
      it 'returns a hash with errors' do
        user = build_stubbed(:user, uuid: '123')
        allow(user).to receive(:reset_password_period_valid?).and_return(true)

        form = ResetPasswordForm.new(user)

        password = 'invalid'

        errors = {
          password:
            ["This password is too short (minimum is #{Devise.password_length.first} characters)"],
        }

        extra = { user_id: '123', profile_deactivated: false }

        expect(form.submit(password: password).to_h).to include(
          success: false,
          errors: errors,
          error_details: hash_including(*errors.keys),
          **extra,
        )
      end
    end

    context 'when both the password and token are valid' do
      it 'sets the user password to the submitted password' do
        user = create(:user, uuid: '123')
        allow(user).to receive(:reset_password_period_valid?).and_return(true)

        form = ResetPasswordForm.new(user)
        password = 'valid password'
        extra = { user_id: '123', profile_deactivated: false }
        user_updater = instance_double(UpdateUser)
        allow(UpdateUser).to receive(:new).
          with(user: user, attributes: { password: password }).and_return(user_updater)

        expect(user_updater).to receive(:call)
        expect(form.submit(password: password).to_h).to eq(
          success: true,
          errors: {},
          **extra,
        )
      end
    end

    context 'when both the password and token are invalid' do
      it 'returns a hash with errors' do
        user = build_stubbed(:user, uuid: '123')
        allow(user).to receive(:reset_password_period_valid?).and_return(false)

        form = ResetPasswordForm.new(user)

        password = 'short'

        errors = {
          password:
            ["This password is too short (minimum is #{Devise.password_length.first} characters)"],
          reset_password_token: ['token_expired'],
        }

        extra = { user_id: '123', profile_deactivated: false }

        expect(form.submit(password: password).to_h).to include(
          success: false,
          errors: errors,
          error_details: hash_including(*errors.keys),
          **extra,
        )
      end
    end

    context 'when the user does not exist in the db' do
      it 'returns a hash with errors' do
        user = User.new

        form = ResetPasswordForm.new(user)
        errors = {
          reset_password_token: ['invalid_token'],
        }

        extra = { user_id: nil, profile_deactivated: false }

        expect(form.submit(password: 'a good and powerful password').to_h).to include(
          success: false,
          errors: errors,
          error_details: hash_including(*errors.keys),
          **extra,
        )
      end
    end

    context 'when the user has an active profile' do
      it 'deactivates the profile' do
        profile = create(:profile, :active, :verified)
        user = profile.user
        user.update(reset_password_sent_at: Time.zone.now)

        form = ResetPasswordForm.new(user)

        result = form.submit(password: 'a good and powerful password')

        expect(result.success?).to eq(true)
        expect(result.extra[:profile_deactivated]).to eq(true)
        expect(profile.reload.active?).to eq(false)
      end
    end

    context 'when the user does not have an active profile' do
      it 'includes that the profile was not deactivated in the form response' do
        user = create(:user)
        user.update(reset_password_sent_at: Time.zone.now)

        form = ResetPasswordForm.new(user)

        result = form.submit(password: 'a good and powerful password')

        expect(result.success?).to eq(true)
        expect(result.extra[:profile_deactivated]).to eq(false)
      end
    end

    context 'when the unconfirmed email address has been confirmed by another account' do
      it 'does not raise an error and is not successful' do
        user = create(:user, :unconfirmed)
        user.update(reset_password_sent_at: Time.zone.now)
        user2 = create(:user)
        create(
          :email_address,
          email: user.email_addresses.first.email,
          user_id: user2.id,
          confirmed_at: Time.zone.now,
        )

        form = ResetPasswordForm.new(user)

        result = form.submit(password: 'a good and powerful password')

        expect(result.success?).to eq(false)
        expect(result.errors).to eq({ reset_password_token: ['token_expired'] })
      end
    end

    it_behaves_like 'strong password', 'ResetPasswordForm'
  end
end
