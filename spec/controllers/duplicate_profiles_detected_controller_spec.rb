require 'rails_helper'

RSpec.describe DuplicateProfilesDetectedController, type: :controller do
  let(:user) { create(:user, :proofed_with_selfie) }
  let(:profile2) { create(:profile, :facial_match_proof) }
  let(:current_sp) do
    create(:service_provider, issuer: 'test-sp', friendly_name: 'Test Service Provider')
  end
  let(:dupe_profile) do
    create(
      :duplicate_profile, profile_ids: [user.active_profile.id, profile2.id],
                          service_provider: current_sp.issuer
    )
  end

  before do
    stub_sign_in(user)
    stub_analytics
    dupe_profile
    allow(controller).to receive(:current_sp).and_return(current_sp)
  end

  describe '#show' do
    context 'when user is not authenticated with 2FA' do
      let(:user) { nil }
      let(:dupe_profile) { nil }

      it 'redirects to sign in page' do
        get :show, params: { source: :sign_in }
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user has an active duplicate profile confirmation' do
      before do
        allow(controller).to receive(:user_session).and_return(session)
      end

      it 'renders the show template' do
        get :show, params: { source: :sign_in }
        expect(response).to render_template(:show)
      end

      it 'initializes the DuplicateProfilesDetectedPresenter' do
        expect(DuplicateProfilesDetectedPresenter).to receive(:new)
          .with(user: user, dupe_profile: dupe_profile)
        get :show, params: { source: :sign_in }
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
        get :show, params: { source: :sign_in }

        expect(@analytics).to have_logged_event(
          :one_account_duplicate_profiles_detected_visited,
        )
      end
    end
  end
end
