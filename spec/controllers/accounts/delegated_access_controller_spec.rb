require 'rails_helper'

RSpec.describe Accounts::DelegatedAccessController do
  let(:user) { create(:user, :fully_registered) }

  before do
    stub_analytics
    stub_sign_in(user)
    allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true)
  end

  it 'requires two-factor authentication' do
    expect(subject).to have_actions(:before, :confirm_two_factor_authenticated)
  end

  describe '#show' do
    it 'renders the page and logs the visit' do
      create(:service_provider, :delegation_service_provider)
      create(:service_provider, :delegation_application)

      get :show

      expect(response).to render_template(:show)
      expect(assigns(:delegated_access).sections.size).to eq(1)
      expect(assigns(:presenter)).to be_a(AccountShowPresenter)
      expect(@analytics).to have_logged_event(:delegated_access_page_visited)
    end
  end
end
