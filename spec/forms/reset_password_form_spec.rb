require 'rails_helper'

RSpec.describe ResetPasswordForm, type: :model do
  let(:user) { create(:user, uuid: '123') }
  subject(:form) { ResetPasswordForm.new(user:) }

  let(:password) { 'a good and powerful password' }
  let(:password_confirmation) { password }
  let(:params) do
    {
      password: password,
      password_confirmation: password,
    }
  end

  it_behaves_like 'password validation'

  describe '#submit' do
    subject(:result) { form.submit(params) }

    context 'when the password is valid but the token has expired' do
      before do
        allow(user).to receive(:reset_password_period_valid?).and_return(false)
      end

      it 'returns a hash with errors' do
        expect(result.to_h).to eq(
          success: false,
          errors: { reset_password_token: ['token_expired'] },
          error_details: { reset_password_token: { token_expired: true } },
          user_id: '123',
          profile_deactivated: false,
          pending_profile_invalidated: false,
          pending_profile_pending_reasons: '',
        )
      end
    end

    context 'when the password is invalid and token is valid' do
      let(:password) { 'invalid' }

      before do
        allow(user).to receive(:reset_password_period_valid?).and_return(true)
      end

      it 'returns a hash with errors' do
        expect(result.to_h).to eq(
          success: false,
          errors: {
            password:
              ["Password must be at least #{Devise.password_length.first} characters long"],
            password_confirmation: [I18n.t(
              'errors.messages.too_short',
              count: Devise.password_length.first,
            )],
          },
          error_details: {
            password: { too_short: true },
            password_confirmation: { too_short: true },
          },
          user_id: '123',
          profile_deactivated: false,
          pending_profile_invalidated: false,
          pending_profile_pending_reasons: '',
        )
      end
    end

    context 'when both the password and token are valid' do
      before do
        allow(user).to receive(:reset_password_period_valid?).and_return(true)
      end

      it 'sets the user password to the submitted password' do
        expect { result }.to change { user.reload.encrypted_password_digest }

        expect(result.to_h).to eq(
          success: true,
          errors: {},
          user_id: '123',
          profile_deactivated: false,
          pending_profile_invalidated: false,
          pending_profile_pending_reasons: '',
        )
      end
    end

    context 'when both the password and token are invalid' do
      let(:password) { 'short' }

      before do
        allow(user).to receive(:reset_password_period_valid?).and_return(false)
      end

      it 'returns a hash with errors' do
        expect(result.to_h).to eq(
          success: false,
          errors: {
            password: [
              t('errors.attributes.password.too_short.other', count: Devise.password_length.first),
            ],
            password_confirmation: [
              t('errors.messages.too_short', count: Devise.password_length.first),
            ],
            reset_password_token: ['token_expired'],
          },
          error_details: {
            password: { too_short: true },
            password_confirmation: { too_short: true },
            reset_password_token: { token_expired: true },
          },
          user_id: '123',
          profile_deactivated: false,
          pending_profile_invalidated: false,
          pending_profile_pending_reasons: '',
        )
      end
    end

    context 'when the user does not exist in the db' do
      let(:user) { User.new }

      it 'returns a hash with errors' do
        expect(result.to_h).to eq(
          success: false,
          errors: { reset_password_token: ['invalid_token'] },
          error_details: { reset_password_token: { invalid_token: true } },
          user_id: nil,
          profile_deactivated: false,
          pending_profile_invalidated: false,
          pending_profile_pending_reasons: '',
        )
      end
    end

    context 'when the user has an active profile' do
      let(:user) { create(:user, :proofed, reset_password_sent_at: Time.zone.now) }

      it 'deactivates the profile' do
        expect(result.success?).to eq(true)
        expect(result.extra[:profile_deactivated]).to eq(true)
        expect(user.profiles.any?(&:active?)).to eq(false)
      end
    end

    context 'when the user does not have an active profile' do
      let(:user) { create(:user, reset_password_sent_at: Time.zone.now) }

      it 'includes that the profile was not deactivated in the form response' do
        expect(result.success?).to eq(true)
        expect(result.extra[:profile_deactivated]).to eq(false)
      end
    end

    context 'when the user has a pending profile' do
      let(:profile) { create(:profile, :verify_by_mail_pending, :in_person_verification_pending) }
      let(:user) { create(:user, reset_password_sent_at: Time.zone.now, profiles: [profile]) }

      it 'includes that the profile was not deactivated in the form response' do
        expect(result.success?).to eq(true)
        expect(result.extra[:pending_profile_invalidated]).to eq(true)
        expect(result.extra[:pending_profile_pending_reasons]).to eq(
          'gpo_verification_pending,in_person_verification_pending',
        )
      end
    end

    context 'when the user does not have a pending profile' do
      let(:user) { create(:user, reset_password_sent_at: Time.zone.now) }

      it 'includes that the profile was not deactivated in the form response' do
        expect(result.success?).to eq(true)
        expect(result.extra[:pending_profile_invalidated]).to eq(false)
        expect(result.extra[:pending_profile_pending_reasons]).to eq('')
      end
    end

    context 'when the unconfirmed email address has been confirmed by another account' do
      let(:user) { create(:user, :unconfirmed, reset_password_sent_at: Time.zone.now) }

      before do
        create(
          :user,
          email_addresses: [create(:email_address, email: user.email_addresses.first.email)],
        )
      end

      it 'does not raise an error and is not successful' do
        expect(result.success?).to eq(false)
        expect(result.errors).to eq({ reset_password_token: ['token_expired'] })
      end
    end

    it_behaves_like 'strong password', 'ResetPasswordForm'
  end
end
