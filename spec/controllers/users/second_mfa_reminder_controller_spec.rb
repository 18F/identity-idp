require 'rails_helper'

RSpec.describe Users::SecondMfaReminderController do
  let(:user) do
    create(
      :user,
      created_at: (IdentityConfig.store.second_mfa_reminder_account_age_in_days + 1).days.ago,
    )
  end

  before do
    stub_sign_in(user) if user
    stub_analytics
  end

  describe '#new' do
    subject(:response) { get :new }

    it 'logs an event' do
      response

      expect(@analytics).to have_logged_event('Second MFA Reminder Visited')
    end

    context 'signed out' do
      let(:user) { nil }

      it 'redirects to sign in' do
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'does not log an event' do
        expect(@analytics).not_to have_logged_event('Second MFA Reminder Visited')
      end
    end
  end

  describe '#create' do
    let(:params) {}
    subject(:response) { post :create, params: }

    context 'user declined' do
      let(:params) { {} }

      it 'logs an event' do
        response

        expect(@analytics).to have_logged_event(
          'Second MFA Reminder Dismissed',
          opted_to_add: false,
        )
      end

      it 'updates user to acknowledge dismissal of prompt' do
        freeze_time do
          expect { response }.to change { user.reload.second_mfa_reminder_dismissed_at }.
            from(nil).to(Time.zone.now)
        end
      end

      it 'redirects to after-signin path' do
        expect(response).to redirect_to(account_path)
      end

      it 'does not assign session value' do
        response

        expect(controller.user_session[:second_mfa_reminder_conversion]).to be_nil
      end
    end

    context 'user opted to add' do
      let(:params) { { add_method: true } }

      it 'logs an event' do
        response

        expect(@analytics).to have_logged_event(
          'Second MFA Reminder Dismissed',
          opted_to_add: true,
        )
      end

      it 'updates user to acknowledge dismissal of prompt' do
        freeze_time do
          expect { response }.to change { user.reload.second_mfa_reminder_dismissed_at }.
            from(nil).to(Time.zone.now)
        end
      end

      it 'redirects to authentication methods setup' do
        expect(response).to redirect_to(authentication_methods_setup_path)
      end

      it 'assigns session value' do
        response

        expect(controller.user_session[:second_mfa_reminder_conversion]).to eq(true)
      end
    end

    context 'signed out' do
      let(:user) { nil }

      it 'redirects to sign in' do
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'does not log an event' do
        expect(@analytics).not_to have_logged_event('Second MFA Reminder Dismissed')
      end
    end
  end
end
