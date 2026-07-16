# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Accounts::HomeController do
  describe '#show' do
    let(:user) { create(:user, :fully_registered) }

    before do
      stub_sign_in(user)
    end

    it 'renders the homepage and assigns the presenter' do
      get :show

      expect(response).to render_template(:show)
      expect(assigns(:presenter)).to be_a(AccountHomePresenter)
    end

    it 'logs the connected services page visit (moved from connected_services)' do
      stub_analytics

      get :show

      expect(@analytics).to have_logged_event(:connected_services_page_visited)
    end

    it 'passes the category param through to the presenter' do
      get :show, params: { category: 'travel' }

      expect(assigns(:presenter).selected_category).to eq('travel')
    end

    context 'when the user is suspended' do
      let(:user) { create(:user, :fully_registered, :suspended) }

      it 'redirects to the please-call page' do
        get :show

        expect(response).to redirect_to(user_please_call_url)
      end
    end
  end
end
