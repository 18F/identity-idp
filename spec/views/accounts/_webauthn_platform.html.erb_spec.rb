require 'rails_helper'

RSpec.describe 'accounts/_webauthn_platform.html.erb' do
  let(:user) do
    create(
      :user,
      webauthn_configurations: create_list(:webauthn_configuration, 2, :platform_authenticator),
    )
  end
  let(:user_session) { { auth_events: [] } }

  subject(:rendered) { render partial: 'accounts/webauthn_platform' }

  before do
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:user_session).and_return(user_session)
  end

  it 'renders a list of platform authenticators' do
    expect(rendered).to have_selector('[role="list"] [role="list-item"]', count: 2)
  end
end
