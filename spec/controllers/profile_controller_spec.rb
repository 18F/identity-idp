require 'rails_helper'

describe ProfileController do
  describe 'before_actions' do
    it 'includes before_actions from AccountStateChecker' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated
      )
    end
  end

  describe '#index' do
    context 'when user has an active identity' do
      it 'renders the profile and does not redirect out of the app' do
        user = create(:user, :signed_up)
        user.identities << Identity.create(
          service_provider: 'http://localhost:3000',
          last_authenticated_at: Time.zone.now
        )

        sign_in user

        get :index

        expect(response).to_not be_redirect
      end
    end

    context 'when a profile has been deactivated by password reset' do
      it 'renders the profile and shows a deactivation banner' do
        user = create(
          :user,
          :signed_up,
          profiles: [build(:profile, :active, :verified, pii: { first_name: 'Jane' })]
        )
        user.active_profile.deactivate(:password_reset)

        sign_in user

        get :index

        expect(response).to_not be_redirect
        expect(assigns(:has_password_reset_profile)).to be(true)
      end
    end
  end
end
