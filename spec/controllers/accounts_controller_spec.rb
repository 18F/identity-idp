require 'rails_helper'

describe AccountsController do
  describe 'before_actions' do
    it 'includes before_actions from AccountStateChecker' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated
      )
    end
  end

  describe '#show' do
    context 'when user has an active identity' do
      it 'renders the profile and does not redirect out of the app' do
        stub_analytics
        user = create(:user, :signed_up)
        user.identities << Identity.create(
          service_provider: 'http://localhost:3000',
          last_authenticated_at: Time.zone.now
        )

        sign_in user

        expect(@analytics).to receive(:track_event).with(Analytics::ACCOUNT_VISIT)

        get :show

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

        view_model = AccountShow.new(
          decrypted_pii: nil,
          personal_key: nil,
          decorated_user: user.decorate
        )
        allow(subject).to receive(:view_model).and_return(view_model)

        get :show

        expect(response).to_not be_redirect
      end
    end

    context 'user has not acknowledged new personal key' do
      it 'redirects to manage_personal_key_url' do
        stub_sign_in
        allow(subject).to receive(:user_session).and_return(personal_key: 'new key')

        get :show

        expect(response).to redirect_to(manage_personal_key_url)
      end
    end
  end
end
