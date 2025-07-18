require 'rails_helper'

RSpec.describe Users::DuplicateProfilesPleaseCallController do
  it 'renders the show template' do
    stub_analytics

    get :show, params: { source: 'foo' }

    expect(@analytics).to have_logged_event(
      :one_account_duplicate_profiles_please_call_visited,
      source: 'foo',
    )
    expect(response).to render_template :show
  end
end
