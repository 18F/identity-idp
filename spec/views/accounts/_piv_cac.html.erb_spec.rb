require 'rails_helper'

RSpec.describe 'accounts/_piv_cac.html.erb' do
  let(:user) do
    user = create(:user)
    2.times do |n|
      create(
        :piv_cac_configuration,
        user: user,
        name: "Configuration #{n}",
        x509_dn_uuid: "unique-uuid-#{n}",
      )
    end
    user
  end

  let(:user_session) { { auth_events: [] } }

  subject(:rendered) { render partial: 'accounts/piv_cac' }

  before do
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:user_session).and_return(user_session)
  end

  it 'renders a list of piv cac configurations' do
    expect(rendered).to have_selector('[role="list"] [role="listitem"]', count: 2)
  end
end
