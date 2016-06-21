require 'rails_helper'

describe DashboardController do
  describe 'before_actions' do
    it 'includes before_actions from AccountStateChecker' do
      expect(subject).to have_filters(
        :before,
        :confirm_two_factor_authenticated
      )
    end
  end

  describe '#index' do
    context 'when user has an active identity' do
      it 'renders the dashboard and does not redirect out of the app' do
        user = create(:user, :signed_up)
        user.identities << Identity.create(
          service_provider: 'http://localhost:3000',
          last_authenticated_at: Time.current
        )

        sign_in user

        get :index

        expect(response).to_not be_redirect
      end
    end
  end
end
