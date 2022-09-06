require 'rails_helper'

describe Idv::SetupErrorsController do
  let(:user) { build_stubbed(:user, :signed_up) }

  before do
    stub_sign_in(user)
  end

  it 'renders the show template' do
    stub_analytics

    expect(@analytics).to receive(:track_event).with('IdV: Verify setup errors visited')

    get :show

    expect(response).to render_template :show
  end
end
