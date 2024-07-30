require 'rails_helper'

RSpec.describe ReactivateAccountController do
  let(:user) { create(:user, profiles: profiles) }
  let(:profiles) { [] }

  before { stub_sign_in(user) }

  describe 'before_actions' do
    it 'requires the user to be logged in' do
      expect(subject).to have_actions(:before, :confirm_two_factor_authenticated)
    end
  end

  describe '#index' do
    context 'with a password reset profile' do
      let(:profiles) { [create(:profile, :verified, :password_reset)] }

      it 'renders the index template' do
        stub_analytics

        get :index

        expect(@analytics).to have_logged_event('Reactivate Account Visited')
        expect(subject).to render_template(:index)
      end
    end

    context 'without a password reset profile' do
      let(:profiles) { [create(:profile, :active)] }
      it 'redirects to the root url' do
        get :index

        expect(response).to redirect_to root_url
      end
    end
  end

  describe '#update' do
    let(:profiles) { [create(:profile, :verified, :password_reset)] }

    it 'redirects user to idv_url' do
      stub_analytics
      put :update

      expect(@analytics).to have_logged_event('Reactivate Account Submitted')
      expect(subject.user_session[:acknowledge_personal_key]).to be_nil
      expect(response).to redirect_to idv_url
    end
  end
end
