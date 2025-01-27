require 'rails_helper'

RSpec.describe SignUp::PasswordsController do
  let(:token) { 'new token' }

  describe '#new' do
    let!(:user) { create(:user, :unconfirmed, confirmation_token: token) }
    subject(:response) { get :new, params: { confirmation_token: token } }

    it 'flashes a message informing the user that they need to set a password' do
      response

      expect(flash.now[:success]).to eq(t('devise.confirmations.confirmed_but_must_set_password'))
    end

    it 'processes valid token' do
      expect(controller).to receive(:process_valid_confirmation_token)

      response
    end

    it 'assigns variables expected to be available in the view' do
      response

      expect(assigns(:password_form)).to be_instance_of(PasswordForm)
      expect(assigns(:email_address)).to be_instance_of(EmailAddress)
      expect(assigns(:forbidden_passwords)).to be_present.and all be_kind_of(String)
      expect(assigns(:confirmation_token)).to be_kind_of(String)
    end

    context 'with invalid confirmation_token' do
      let!(:user) do
        create(
          :user,
          :unconfirmed,
          confirmation_token: token,
          confirmation_sent_at: (IdentityConfig.store.add_email_link_valid_for_hours + 1).hours.ago,
        )
      end

      it 'redirects to sign up page' do
        expect(response).to redirect_to(sign_up_register_url)
      end
    end
  end

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
    let(:success_properties) { { success: true } }

    context 'with valid password' do
      let!(:user) { create(:user, :unconfirmed, confirmation_token: token) }

      before do
        stub_analytics
      end

      it 'tracks analytics' do
        subject

        expect(@analytics).to have_logged_event(
          'Password Creation',
          success: true,
          user_id: user.uuid,
          request_id_present: false,
        )
      end

      it 'confirms the user' do
        subject

        user.reload
        expect(user.valid_password?('NewVal!dPassw0rd')).to eq true
        expect(user.confirmed?).to eq true
      end

      it 'initializes user session' do
        response

        expect(controller.user_session).to match(
          'unique_session_id' => kind_of(String),
          'last_request_at' => kind_of(Numeric),
          new_device: false,
          in_account_creation_flow: true,
          web_locale: 'en',
        )
      end
    end

    context 'with an invalid password' do
      let!(:user) { create(:user, :unconfirmed, confirmation_token: token) }

      before do
        stub_analytics
      end

      context 'with a password that is too short' do
        let(:password) { 'NewVal' }
        let(:password_confirmation) { 'NewVal' }

        it 'tracks an invalid password event' do
          subject

          expect(@analytics).to have_logged_event(
            'Password Creation',
            success: false,
            error_details: {
              password: { too_short: true },
              password_confirmation: { too_short: true },
            },
            user_id: user.uuid,
            request_id_present: false,
          )
        end
      end

      context 'when password confirmation does not match' do
        let(:password) { 'NewVal!dPassw0rd' }
        let(:password_confirmation) { 'bad match password' }

        it 'tracks invalid password_confirmation error' do
          subject

          expect(@analytics).to have_logged_event(
            'Password Creation',
            success: false,
            error_details: {
              password_confirmation: { mismatch: true },
            },
            user_id: user.uuid,
            request_id_present: false,
          )
        end
      end
    end

    context 'with an with an invalid confirmation_token' do
      let(:token) { 'new token' }
      let(:invalid_confirmation_sent_at) do
        Time.zone.now - (IdentityConfig.store.add_email_link_valid_for_hours.hours.in_seconds + 1)
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
        validator = EmailConfirmationTokenValidator.new(email_address: user.email_addresses.first)
        result = validator.submit
        expect(result.success?).to eq false

        subject

        user.reload
        expect(user.valid_password?(password)).to eq false
        expect(user.confirmed?).to eq false
        expect(response).to redirect_to(sign_up_register_url)
      end
    end
  end
end
