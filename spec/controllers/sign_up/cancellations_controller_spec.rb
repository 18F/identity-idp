require 'rails_helper'

describe SignUp::CancellationsController do
  describe '#new' do
    it 'tracks the event in analytics when referer is nil' do
      stub_sign_in
      stub_analytics
      properties = { request_came_from: 'no referer' }

      expect(@analytics).to receive(:track_event).with(
        Analytics::USER_REGISTRATION_CANCELLATION, properties
      )

      get :new
    end

    it 'tracks the event in analytics when referer is present' do
      stub_sign_in
      stub_analytics
      request.env['HTTP_REFERER'] = 'http://example.com/'
      properties = { request_came_from: 'users/sessions#new' }

      expect(@analytics).to receive(:track_event).with(
        Analytics::USER_REGISTRATION_CANCELLATION, properties
      )

      get :new
    end
  end

  describe '#destroy' do
    it 'redirects if no user is present' do
      delete :destroy

      expect(response).to redirect_to(sign_up_email_resend_url)
    end

    it 'redirects if user has completed sign up' do
      stub_sign_in

      delete :destroy

      expect(response).to redirect_to(root_url)
    end

    it 'destroys the current_user if user has set password but not added 2FA' do
      user = create(:user)
      stub_sign_in_before_2fa(user)

      expect { delete :destroy }.to change(User, :count).by(-1)
      expect(response).to redirect_to(root_url)
      expect(flash.now[:success]).to eq t('sign_up.cancel.success')
    end

    it 'redirects if confirmation_token is invalid' do
      confirmation_token = '1'

      create(
        :user, email_addresses: [
          build(
            :email_address,
            confirmed_at: nil,
            confirmation_token: '2',
          ),
        ]
      )
      subject.session[:user_confirmation_token] = confirmation_token
      delete :destroy

      expect(flash[:error]).to eq t('errors.messages.confirmation_invalid_token')
      expect(response).to redirect_to(sign_up_email_resend_url)
    end

    it 'redirects if confirmation_token is expired' do
      confirmation_token = '1'
      invalid_confirmation_sent_at =
        Time.zone.now - (IdentityConfig.store.add_email_link_valid_for_hours.hours.to_i + 1)

      create(
        :user, email_addresses: [
          build(
            :email_address,
            confirmed_at: nil,
            confirmation_sent_at: invalid_confirmation_sent_at,
            confirmation_token: confirmation_token,
          ),
        ]
      )
      subject.session[:user_confirmation_token] = confirmation_token

      delete :destroy
      expect(response).to redirect_to(sign_up_email_resend_url)
      expect(flash[:error]).to eq t('errors.messages.confirmation_period_expired')
    end

    it 'redirects to the branded start page if the user came from an SP' do
      user = create(:user)
      stub_sign_in_before_2fa(user)
      session[:sp] = { issuer: 'http://localhost:3000', request_id: 'foo' }

      delete :destroy

      expect(response).
        to redirect_to new_user_session_path(request_id: 'foo')
    end

    it 'tracks the event in analytics when referer is nil' do
      user = create(:user)
      stub_sign_in_before_2fa(user)
      stub_analytics
      properties = { request_came_from: 'no referer' }

      expect(@analytics).to receive(:track_event).with('Account Deletion Requested', properties)

      delete :destroy
    end

    it 'tracks the event in analytics when referer is present' do
      user = create(:user)
      stub_sign_in_before_2fa(user)
      stub_analytics
      request.env['HTTP_REFERER'] = 'http://example.com/'
      properties = { request_came_from: 'users/sessions#new' }

      expect(@analytics).to receive(:track_event).with('Account Deletion Requested', properties)

      delete :destroy
    end

    it 'calls ParseControllerFromReferer' do
      user = create(:user)
      stub_sign_in_before_2fa(user)
      expect_any_instance_of(ParseControllerFromReferer).to receive(:call).and_call_original

      delete :destroy
    end
  end
end
