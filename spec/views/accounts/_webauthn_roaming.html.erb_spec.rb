require 'rails_helper'

RSpec.describe 'accounts/_webauthn_roaming.html.erb' do
  let(:user) do
    create(
      :user,
      webauthn_configurations: create_list(:webauthn_configuration, 2),
    )
  end
  let(:user_session) { { auth_events: [] } }

  subject(:rendered) { render partial: 'accounts/webauthn_roaming' }

  before do
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:user_session).and_return(user_session)
  end

  it 'renders a list of roaming authenticators' do
    expect(rendered).to have_selector('[role="list"] [role="listitem"]', count: 2)
  end
end
