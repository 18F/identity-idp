require 'rails_helper'

RSpec.describe DuplicateProfilesDetectedController, type: :controller do
  let(:user) { create(:user, :proofed_with_selfie) }
  let(:profile2) { create(:profile, :facial_match_proof) }
  let(:current_sp) do
    create(:service_provider, issuer: 'test-sp', friendly_name: 'Test Service Provider')
  end

  before do
    stub_sign_in(user)
    stub_analytics
    session[:duplicate_profile_ids] = [profile2.id]
    allow(controller).to receive(:current_sp).and_return(current_sp)
  end

  describe '#show' do
    context 'when user is not authenticated with 2FA' do
      let(:user) { nil }

      it 'redirects to sign in page' do
        get :show
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user has an active duplicate profile confirmation' do
      before do
        allow(controller).to receive(:user_session).and_return(session)
      end

      it 'renders the show template' do
        get :show
        expect(response).to render_template(:show)
      end

      it 'initializes the DuplicateProfilesDetectedPresenter' do
        expect(DuplicateProfilesDetectedPresenter).to receive(:new)
          .with(user: user, user_session: session)
        get :show
      end

      it 'enqueues an alert job for each duplicate profile' do
        expect(AlertUserDuplicateProfileDiscoveredJob).to receive(:perform_later).with(
          user: profile2.user,
          agency: current_sp.friendly_name,
          type: AlertUserDuplicateProfileDiscoveredJob::SIGN_IN_ATTEMPTED,
        )

        controller.send(:notify_users_of_duplicate_profile_sign_in)
      end

      it 'logs an event' do
        get :show

        expect(@analytics).to have_logged_event(
          :one_account_duplicate_profiles_detected,
        )
      end
    end
  end

  describe '#do_not_recognize_profiles' do
    before do
      allow(controller).to receive(:user_session).and_return(session)
    end

    it 'logs an event' do
      post :do_not_recognize_profiles

      expect(@analytics).to have_logged_event(
        :one_account_unknown_profile_detected,
      )
    end
  end

  describe '#recognize_all_profiles' do
    before do
      allow(controller).to receive(:user_session).and_return(session)
    end

    it 'logs an analytics event' do
      post :recognize_all_profiles
      expect(@analytics).to have_logged_event
    end
  end

  describe '#redirect_unless_user_has_active_duplicate_profile_confirmation' do
    context 'when user does not have an active profile' do
      before do
        allow(controller).to receive(:current_user).and_return(user)
        allow(user).to receive(:active_profile).and_return(nil)
        allow(controller).to receive(:confirm_two_factor_authenticated).and_return(true)
      end

      it 'updates dupe profile confirmation' do
        get :show
      end
    end
  end
end
