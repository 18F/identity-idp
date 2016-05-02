require 'rails_helper'

describe DashboardController do
  describe '#index' do
    let(:user) { create(:user, :signed_up) }

    before { sign_in user }

    after { session[:declined_quiz] = nil }

    context 'when user needs to verify their identity' do
      xit 'redirects to idp_index_path' do
        allow(subject.current_user).to receive(:needs_idv?).and_return(true)

        get :index

        expect(response).to redirect_to idp_index_path
      end
    end

    context 'when user does not need to verify their identity' do
      it 'does not redirect to quiz' do
        allow(subject.current_user).to receive(:needs_idv?).and_return(false)

        get :index

        expect(response).to_not be_redirect
      end
    end

    context 'when quiz has been declined' do
      it 'does not redirect to quiz' do
        session[:declined_quiz] = true
        get :index

        expect(response).to_not be_redirect
      end
    end
  end

  context 'when a user with an identity but no IAL token gets sent to dashboard' do
    xit 'redirects to the sp_initiated_login_url or acs_url' do
      user = create(:user, :signed_up)

      user.set_active_identity(
        'http://test.host', 'http://idmanagement.gov/ns/assurance/loa/1', true
      )

      sign_in user
      get :index

      expect(response).to redirect_to 'http://test.host/test/saml'
    end
  end

  describe 'before_actions' do
    it 'includes before_actions from AccountStateChecker' do
      expect(subject).to have_filters(
        :before,
        :authenticate_user!,
        :confirm_two_factor_setup,
        :confirm_two_factor_authenticated,
        :confirm_idv_status
      )
    end
  end
end
