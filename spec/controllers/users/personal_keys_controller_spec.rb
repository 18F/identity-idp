require 'rails_helper'

describe Users::PersonalKeysController do
  describe '#show' do
    context 'when user signed in' do
      before do
        stub_sign_in
      end

      it 'tracks an analytics event' do
        stub_analytics

        expect(@analytics).to receive(:track_event).with(Analytics::PROFILE_PERSONAL_KEY_CREATE)

        get :show
      end

      it 'generates a new personal key' do
        generator = instance_double(PersonalKeyGenerator)
        allow(PersonalKeyGenerator).to receive(:new).
          with(subject.current_user).and_return(generator)

        expect(generator).to receive(:create)

        get :show
      end

      it 'populates the flash when resending code' do
        expect(flash[:sucess]).to be_nil

        get :show, params: { resend: true }
        expect(flash.now[:success]).to eq t('notices.send_code.personal_key')
      end
    end

    context 'when there is no session (signed out or locked out), and the user reloads the page' do
      it 'redirects to the home page' do
        expect(controller.user_session).to be_nil

        get :show

        expect(response).to redirect_to(new_user_session_path)
      end
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
      it 'redirects to the reactiveate_profile_path' do
        user = create(:user, :signed_up)
        create(:profile, :active, :verified, user: user, pii: { first_name: 'Jane' })
        user.active_profile.deactivate(:password_reset)
        sign_in user

        patch :update

        expect(response).to redirect_to reactivate_account_url
      end
    end
  end
end
