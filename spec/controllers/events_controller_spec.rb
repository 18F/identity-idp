require 'rails_helper'

RSpec.describe EventsController do
  describe '#show' do
    let(:user) { create(:user, :fully_registered) }
    let(:device) { create(:device, user:) }

    before { stub_sign_in(user) }

    it 'renders the legacy no-card layout by default' do
      get :show, params: { id: device.id }

      expect(response).to render_template(layout: 'layouts/no_card')
    end

    it 'renders the NDS account shell in the NDS layout' do
      allow(controller).to receive(:nds_layout?).and_return(true)

      get :show, params: { id: device.id }

      expect(response).to render_template(layout: 'layouts/nds/account_side_nav')
    end
  end
end
