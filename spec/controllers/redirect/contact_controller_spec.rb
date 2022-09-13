require 'rails_helper'

describe Redirect::ContactController do
  before do
    stub_analytics
  end

  describe '#show' do
    it 'redirects to contact page' do
      redirect_url = IdentityConfig.store.idv_contact_url

      get :show

      expect(response).to redirect_to redirect_url
      expect(@analytics).to have_logged_event(
        'External Redirect',
        redirect_url: redirect_url,
      )
    end
  end
end
