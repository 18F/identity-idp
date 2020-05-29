require 'rails_helper'

describe Users::PersonalKeysController do
  describe '#show' do
    context 'when user signed in but user_session[:personal_key] is not present' do
      it 'redirects to account_url' do
        stub_sign_in

        get :show

        expect(response).to redirect_to(account_url)
      end
    end

    context 'when there is no session (signed out or locked out), and the user reloads the page' do
      it 'redirects to the home page' do
        expect(controller.user_session).to be_nil

        get :show

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    it 'tracks the page visit when there is a personal key in the user session' do
      stub_sign_in
      controller.user_session[:personal_key] = 'foo'
      stub_analytics
      analytics_hash = { personal_key_present: true }

      expect(@analytics).to receive(:track_event).
        with(Analytics::PERSONAL_KEY_VIEWED, analytics_hash)

      get :show
    end

    it 'tracks the page visit when there is no personal key in the user session' do
      stub_sign_in
      stub_analytics
      analytics_hash = { personal_key_present: false }

      expect(@analytics).to receive(:track_event).
        with(Analytics::PERSONAL_KEY_VIEWED, analytics_hash)

      get :show
    end

    it 'does not generate a new personal key to avoid CSRF attacks' do
      stub_sign_in

      generator = instance_double(PersonalKeyGenerator)
      allow(PersonalKeyGenerator).to receive(:new).
        with(subject.current_user).and_return(generator)

      expect(generator).to_not receive(:create)

      get :show
    end
  end

  describe '#update' do
    context 'user does not need to reactivate account' do
      it 'redirects to the profile page' do
        stub_sign_in

        patch :update

        expect(response).to redirect_to account_url
      end
    end

    context 'user needs to reactive account' do
      it 'redirects to the sign up completed url for ial 1' do
        controller.session[:sp] = { ial2: false }

        user = create(:user, :signed_up)
        create(:profile, :active, :verified, user: user, pii: { first_name: 'Jane' })
        user.active_profile.deactivate(:password_reset)
        sign_in user

        patch :update

        expect(response).to redirect_to sign_up_completed_url
      end

      it 'redirects to the reactivate account url for ial 2' do
        controller.session[:sp] = { ial2: true }

        user = create(:user, :signed_up)
        create(:profile, :active, :verified, user: user, pii: { first_name: 'Jane' })
        user.active_profile.deactivate(:password_reset)
        sign_in user

        patch :update

        expect(response).to redirect_to reactivate_account_url
      end
    end

    it 'deletes user_session[:personal_key]' do
      stub_sign_in
      controller.user_session[:personal_key] = 'foo'

      post :update

      expect(controller.user_session[:personal_key]).to be_nil
    end

    it 'tracks CSRF errors' do
      stub_sign_in
      stub_analytics
      analytics_hash = {
        controller: 'users/personal_keys#update',
        user_signed_in: true,
      }
      allow(controller).to receive(:update).and_raise(ActionController::InvalidAuthenticityToken)

      expect(@analytics).to receive(:track_event).
        with(Analytics::INVALID_AUTHENTICITY_TOKEN, analytics_hash)

      post :update

      expect(response).to redirect_to new_user_session_url
      expect(flash[:alert]).to eq t('errors.invalid_authenticity_token')
    end
  end

  describe '#create' do
    it 'generates a new personal key, tracks an analytics event, and redirects' do
      stub_sign_in(create(:user, :with_phone))
      stub_analytics

      generator = instance_double(PersonalKeyGenerator)
      allow(PersonalKeyGenerator).to receive(:new).
        with(subject.current_user).and_return(generator)

      expect(generator).to receive(:create)
      expect(@analytics).to receive(:track_event).with(Analytics::PROFILE_PERSONAL_KEY_CREATE)
      expect(@analytics).to receive(:track_event).with(
        Analytics::PROFILE_PERSONAL_KEY_CREATE_NOTIFICATIONS,
        hash_including(emails: 1, sms_message_ids: ['fake-message-id']),
      )

      post :create

      expect(response).to redirect_to manage_personal_key_path
    end

    it 'tracks CSRF errors' do
      stub_sign_in
      stub_analytics
      analytics_hash = {
        controller: 'users/personal_keys#create',
        user_signed_in: true,
      }
      allow(controller).to receive(:create).and_raise(ActionController::InvalidAuthenticityToken)

      expect(@analytics).to receive(:track_event).
        with(Analytics::INVALID_AUTHENTICITY_TOKEN, analytics_hash)

      post :create

      expect(response).to redirect_to new_user_session_url
      expect(flash[:alert]).to eq t('errors.invalid_authenticity_token')
    end
  end
end
