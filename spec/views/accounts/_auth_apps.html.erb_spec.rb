require 'rails_helper'

RSpec.describe 'accounts/_auth_apps.html.erb' do
  let(:user) do
    create(
      :user,
      auth_app_configurations: create_list(:auth_app_configuration, 2),
    )
  end
  let(:user_session) { { auth_events: [] } }

  subject(:rendered) { render partial: 'accounts/auth_apps' }

  before do
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:user_session).and_return(user_session)
  end

  it 'renders a list of auth apps' do
    expect(rendered).to have_selector('[role="list"] [role="listitem"]', count: 2)
  end
end
