require 'rails_helper'

RSpec.describe Users::PleaseCallController do
  let(:user) { create(:user, :suspended) }

  before do
    stub_sign_in(user)
  end

  it 'renders the show template' do
    stub_analytics

    expect(@analytics).to have_logged_event(
      'User Suspension: Please call visited',
    )

    get :show

    expect(response).to render_template :show
  end
end
