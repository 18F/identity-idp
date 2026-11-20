require 'rails_helper'

RSpec.describe Accounts::HistoryController do
  describe '#show' do
    let(:user) { create(:user, :fully_registered) }

    before { stub_sign_in(user) }

    it 'renders the legacy account side nav layout by default' do
      get :show

      expect(response).to render_template(layout: 'layouts/account_side_nav')
    end

    it 'renders the NDS account shell in the NDS layout' do
      allow(controller).to receive(:nds_layout?).and_return(true)

      get :show

      expect(response).to render_template(layout: 'layouts/nds/account_side_nav')
    end
  end
end
