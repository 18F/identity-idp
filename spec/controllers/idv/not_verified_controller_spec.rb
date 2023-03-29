require 'rails_helper'

describe Idv::NotVerifiedController do
  let(:user) { build_stubbed(:user, :signed_up) }

  before do
    stub_sign_in(user)
  end

  it 'renders the show template' do
    stub_analytics

    expect(@analytics).to receive(:track_event).with(
      'IdV: Not verified visited',
    )

    get :show

    expect(response).to render_template :show
  end
end
