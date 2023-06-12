require 'rails_helper'

RSpec.describe SignUp::PasswordsController do
  let(:token) { 'new token' }

  describe '#create' do
    subject(:response) { post :create, params: params }
    let(:params) do
      {
        password_form: {
          password: password,
          password_confirmation: password_confirmation,
        },
        confirmation_token: token,
      }
    end
    let(:password) { 'NewVal!dPassw0rd' }
    let(:password_confirmation) { password }
    let(:success_properties) { { success: true, failure_reason: nil } }

    context 'with valid password' do
      let!(:user) { create(:user, :unconfirmed, confirmation_token: token) }
      let(:analytics_hash) do
        {
          success: true,
          errors: {},
          user_id: user.uuid,
        }
      end

      before do
        stub_analytics
        stub_attempts_tracker
      end

      it 'tracks analytics' do
        expect(@analytics).to receive(:track_event).with(
          'User Registration: Email Confirmation',
          analytics_hash.merge({ error_details: nil }),
        )
        expect(@analytics).to receive(:track_event).with(
          'Password Creation',
          analytics_hash.merge({ request_id_present: false }),
        )

        expect(@irs_attempts_api_tracker).to receive(:user_registration_password_submitted).
          with(success_properties)
        expect(@irs_attempts_api_tracker).not_to receive(:user_registration_email_confirmation)

        subject
      end

      it 'confirms the user' do
        subject

        user.reload
        expect(user.valid_password?('NewVal!dPassw0rd')).to eq true
        expect(user.confirmed?).to eq true
      end
    end

    context 'with an invalid password' do
      let!(:user) { create(:user, :unconfirmed, confirmation_token: token) }
      let(:analytics_hash) do
        {
          success: false,
          errors: errors,
          error_details: error_details,
          user_id: user.uuid,
          request_id_present: false,
        }
      end

      before do
        stub_analytics
        stub_attempts_tracker
      end

      context 'with a password that is too short' do
        let(:password) { 'NewVal' }
        let(:password_confirmation) { 'NewVal' }
        let(:errors) do
          {
            password:
              [t(
                'errors.attributes.password.too_short.other',
                count: Devise.password_length.first,
              )],
            password_confirmation:
              ["is too short (minimum is #{Devise.password_length.first} characters)"],
          }
        end
        let(:error_details) do
          {
            password: [:too_short],
            password_confirmation: [:too_short],
          }
        end

        it 'tracks an invalid password event' do
          expect(@analytics).to receive(:track_event).
            with(
              'User Registration: Email Confirmation',
              { errors: {}, error_details: nil, success: true, user_id: user.uuid },
            )
          expect(@analytics).to receive(:track_event).
            with('Password Creation', analytics_hash)

          expect(@irs_attempts_api_tracker).to receive(:user_registration_password_submitted).
            with(
              success: false,
              failure_reason: error_details,
            )
          expect(@irs_attempts_api_tracker).not_to receive(:user_registration_email_confirmation)

          subject
        end
      end

      context 'when password confirmation does not match' do
        let(:password) { 'NewVal!dPassw0rd' }
        let(:password_confirmation) { 'bad match password' }
        let(:errors) do
          {
            password_confirmation:
              [t('errors.messages.password_mismatch')],
          }
        end
        let(:error_details) do
          {
            password_confirmation: [t('errors.messages.password_mismatch')],
          }
        end

        it 'tracks invalid password_confirmation error' do
          expect(@analytics).to receive(:track_event).
            with(
              'User Registration: Email Confirmation',
              { errors: {}, error_details: nil, success: true, user_id: user.uuid },
            )

          expect(@analytics).to receive(:track_event).
            with('Password Creation', analytics_hash)

          subject
        end
      end
    end

    context 'with an with an invalid confirmation_token' do
      let(:token) { 'new token' }
      let(:invalid_confirmation_sent_at) do
        Time.zone.now - (IdentityConfig.store.add_email_link_valid_for_hours.hours.to_i + 1)
      end
      let!(:user) do
        create(
          :user,
          :unconfirmed,
          confirmation_token: token,
          confirmation_sent_at: invalid_confirmation_sent_at,
        )
      end

      it 'rejects when confirmation_token is invalid' do
        validator = EmailConfirmationTokenValidator.new(user.email_addresses.first)
        result = validator.submit
        expect(result.success?).to eq false

        subject

        user.reload
        expect(user.valid_password?(password)).to eq false
        expect(user.confirmed?).to eq false
        expect(response).to redirect_to(sign_up_email_resend_url)
      end
    end
  end

  describe '#new' do
    render_views
    it 'instructs crawlers to not index this page' do
      token = 'foo token'
      create(:user, :unconfirmed, confirmation_token: token)
      get :new, params: { confirmation_token: token }

      expect(response.body).to match('<meta content="noindex,nofollow" name="robots" />')
    end

    it 'rejects when confirmation_token is invalid' do
      invalid_confirmation_sent_at =
        Time.zone.now - (IdentityConfig.store.add_email_link_valid_for_hours.hours.to_i + 1)
      create(
        :user,
        :unconfirmed,
        confirmation_token: token,
        confirmation_sent_at: invalid_confirmation_sent_at,
      )

      get :new, params: { confirmation_token: token }
      expect(response).to redirect_to(sign_up_email_resend_url)
    end
  end
end
