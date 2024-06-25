require 'rails_helper'

RSpec.describe Users::PasswordCompromisedController, allowed_extra_analytics: [:*] do
  describe '#show' do
    let(:user) { create(:user) }
    context 'check_password_enabled is not enabled' do
      before do
        allow(FeatureManagement).to receive(:check_password_enabled?).and_return(false)
        stub_sign_in(user)
        stub_analytics
      end

      it 'redirects to account page' do
        get :show
        expect(response).to redirect_to account_url
      end
    end

    context 'check_password_enabled is enabled' do
      before do
        allow(FeatureManagement).to receive(:check_password_enabled?).and_return(true)
        stub_sign_in(user)
        stub_analytics
        session[:redirect_to_change_password] = true
      end

      it 'renders password compromised page' do
        get :show
        expect(response).to render_template(:show)
        expect(session[:redirect_to_change_password]).to be_nil
      end

      it 'logs analytics for password compromised visited' do
        get :show
        expect(@analytics).to have_logged_event(:user_password_compromised_visited)
      end
    end
  end

  describe '#update' do
    let(:user) { create(:user) }
    context 'check_password_enabled is not enabled' do
      before do
        allow(FeatureManagement).to receive(:check_password_enabled?).and_return(false)
        stub_sign_in(user)
        stub_analytics
      end

      it 'redirects to account page' do
        post :update
        expect(response).to redirect_to account_url
      end
    end

    context 'check_password_enabled is enabled' do
      let(:password) { 'salty new password' }
      let(:params) do
        {
          password: password,
          password_confirmation: password,
        }
      end
      before do
        allow(FeatureManagement).to receive(:check_password_enabled?).and_return(true)
        stub_sign_in(user)
        stub_analytics
      end

      context 'proper password form submission' do
        it 'updates the user password and logs analytic event' do
          allow(@analytics).to receive(:track_event)
          patch :update, params: { update_user_password_form: params }

          expect(@analytics).to have_received(:track_event).with(
            'Password Changed',
            success: true,
            errors: {},
            error_details: nil,
            pending_profile_present: false,
            active_profile_present: false,
            user_id: subject.current_user.uuid,
            original_password_compromised: true,
          )
          expect(response).to redirect_to account_url
          expect(flash[:info]).to eq t('notices.password_changed')
        end

        it 'sends email notifying user of password change' do
          allow(@analytics).to receive(:track_event)

          patch :update, params: { update_user_password_form: params }
          expect_delivered_email_count(1)
        end

        it 'sends a security event' do
          security_event = PushNotification::PasswordResetEvent.new(user: user)
          expect(PushNotification::HttpPush).to receive(:deliver).with(security_event)

          patch :update, params: { update_user_password_form: params }
        end
      end

      context 'improper password form submission' do
        let(:password) { 'new' }
        let(:params) do
          {
            password: password,
            password_confirmation: password,
          }
        end

        it 'does not create a password_changed user Event' do
          stub_sign_in

          expect(controller).to_not receive(:create_user_event)

          patch :update, params: { update_user_password_form: params }
        end

        it 'renders show page' do
          patch :update, params: { update_user_password_form: params }
          expect(response).to render_template(:show)
        end
      end
    end
  end
end
