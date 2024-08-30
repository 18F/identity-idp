require 'rails_helper'

RSpec.describe Users::PivCacRecommendedController do
  describe 'New user' do
    let(:user) { create(:user, email: 'example@gsa.gov') }
    let!(:federal_domain) { create(:federal_email_domain, name: 'gsa.gov') }
    before do
      stub_sign_in_before_2fa(user)
      stub_analytics
      controller.user_session[:in_account_creation_flow] = true
    end

    context '#show' do
      context 'with user without proper email' do
        let(:user) { create(:user, email: 'example@example.com') }

        it 'redirects back to sign in path page' do
          get :show
          expect(response).to redirect_to(account_path)
        end
      end
    end

    it 'logs analytic event' do
      get :show

      expect(@analytics).to have_logged_event(:piv_cac_recommended_visited)
    end
  end

  describe 'Sign in flow' do
    let(:user) { create(:user, :with_phone, { email: 'example@gsa.gov' }) }
    let!(:federal_domain) { create(:federal_email_domain, name: 'gsa.gov') }
    before do
      stub_analytics
      stub_sign_in(user)
      user.reload
    end

    context '#show' do
      context 'with user without proper email' do
        let(:user) { create(:user, :with_phone, { email: 'example@example.com' }) }

        it 'redirects back to account page' do
          get :show
          expect(response).to redirect_to(account_path)
        end
      end
    end
  end

  context '#confirm' do
    let(:user) { create(:user, email: 'example@gsa.gov') }
    let!(:federal_domain) { create(:federal_email_domain, name: 'gsa.gov') }
    before do
      stub_sign_in_before_2fa(user)
      stub_analytics
      controller.user_session[:in_account_creation_flow] = true
    end

    it 'directs user to piv cac page' do
      post :confirm

      expect(response).to redirect_to(setup_piv_cac_path)
    end

    it 'sets piv_cac recommended as set' do
      post :confirm

      user.reload
      expect(user.piv_cac_recommended_dismissed_at).to be_truthy
    end

    it 'logs analytics' do
      post :confirm

      expect(@analytics).to have_logged_event(:piv_cac_recommended, action: :accepted)
    end
  end

  context '#skip' do
    let(:user) { create(:user, email: 'example@gsa.gov') }
    let!(:federal_domain) { create(:federal_email_domain, name: 'gsa.gov') }
    before do
      stub_sign_in_before_2fa(user)
      stub_analytics
      controller.user_session[:in_account_creation_flow] = true
    end

    it 'directs user to after set up page' do
      post :skip

      expect(response).to redirect_to(account_path)
    end

    it 'sets piv_cac recommended as set' do
      post :skip

      user.reload
      expect(user.piv_cac_recommended_dismissed_at).to be_truthy
    end

    it 'logs analytics' do
      post :skip

      expect(@analytics).to have_logged_event(:piv_cac_recommended, action: :skipped)
    end
  end
end
