require 'rails_helper'

RSpec.describe Idv::PhoneRequiredController do
  let(:user) { create(:user, :fully_registered) }

  before do
    stub_sign_in(user)
    stub_analytics
  end

  describe '#show' do
    it 'renders and logs the visit' do
      get :show

      expect(response).to render_template(:show)
      expect(@analytics).to have_logged_event(:idv_phone_required_visited)
    end
  end
end
