require 'rails_helper'

describe Idv::VerifyErrorsController do
  let(:user) { build_stubbed(:user, :signed_up) }

  before do
    stub_sign_in(user)
  end

  it 'renders the show template' do
    get :show

    expect(response).to render_template :show
  end
end
