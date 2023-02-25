require 'rails_helper'

describe AccountsController do
  describe 'before_actions' do
    it 'includes before_actions from AccountStateChecker' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
      )
    end
  end

  describe '#show' do
    context 'when user has an active identity' do
      it 'renders the profile and does not redirect out of the app' do
        stub_analytics
        user = create(:user, :signed_up)
        user.identities << ServiceProviderIdentity.create(
          service_provider: 'http://localhost:3000',
          last_authenticated_at: Time.zone.now,
        )

        sign_in user

        expect(@analytics).to receive(:track_event).with('Account Page Visited')

        get :show

        expect(response).to_not be_redirect
      end
    end

    context 'when a profile has been deactivated by password reset' do
      it 'renders the profile and shows a deactivation banner' do
        user = create(
          :user,
          :signed_up,
          profiles: [build(:profile, :active, :verified, pii: { first_name: 'Jane' })],
        )
        user.active_profile.deactivate(:password_reset)

        sign_in user

        presenter = AccountShowPresenter.new(
          decrypted_pii: nil,
          personal_key: nil,
          sp_session_request_url: nil,
          sp_name: nil,
          decorated_user: user.decorate,
          locked_for_session: false,
        )
        allow(subject).to receive(:presenter).and_return(presenter)

        get :show

        expect(response).to_not be_redirect
      end
    end

    context 'when a profile is pending' do
      render_views
      it 'renders the pending profile banner' do
        user = create(
          :user,
          :signed_up,
          profiles: [build(:profile, deactivation_reason: :gpo_verification_pending)],
        )

        sign_in user
        get :show

        expect(response).to render_template(:show)
        expect(response).to render_template(partial: 'accounts/_pending_profile_gpo')
      end
    end

    context 'when logging in with piv/cac' do
      context 'when the user is proofed' do
        it 'renders a locked profile' do
          user = create(
            :user,
            :signed_up,
            profiles: [build(:profile, :active, :verified, pii: { first_name: 'Jane' })],
          )

          sign_in user

          presenter = AccountShowPresenter.new(
            decrypted_pii: nil,
            personal_key: nil,
            sp_session_request_url: nil,
            sp_name: nil,
            decorated_user: user.decorate,
            locked_for_session: false,
          )
          allow(subject).to receive(:presenter).and_return(presenter)

          get :show

          expect(response).to_not be_redirect
        end
      end
    end
  end
end
