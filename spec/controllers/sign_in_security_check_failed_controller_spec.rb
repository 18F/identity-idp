require 'rails_helper'

RSpec.describe SignInSecurityCheckFailedController do
  let(:user) { build_stubbed(:user, :fully_registered) }

  before do
    stub_sign_in(user)
  end

  it 'renders the show template' do
    stub_analytics

    get :show

    expect(@analytics).to have_logged_event(:sign_in_security_check_failed_visited)

    expect(response).to render_template :show
  end
end
