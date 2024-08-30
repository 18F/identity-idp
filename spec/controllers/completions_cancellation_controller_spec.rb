require 'rails_helper'

RSpec.describe CompletionsCancellationController do
  let(:user) { build_stubbed(:user, :fully_registered) }

  before do
    stub_sign_in(user)
  end

  it 'renders the show template' do
    stub_analytics

    get :show

    expect(@analytics).to have_logged_event(:completions_cancellation_visited)

    expect(response).to render_template :show
  end
end
