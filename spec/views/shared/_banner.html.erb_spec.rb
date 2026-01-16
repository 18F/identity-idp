require 'rails_helper'

RSpec.describe 'shared/_banner.html.erb' do
  let(:sp_with_logo) do
    build_stubbed(
      :service_provider, logo: 'generic.svg', friendly_name: 'Best SP ever'
    )
  end
  let(:decorated_sp_session) do
    ServiceProviderSession.new(
      sp: sp_with_logo,
      view_context: '',
      sp_session: {},
      service_provider_request: nil,
    )
  end

  before do
    allow(view).to receive(:decorated_sp_session).and_return(decorated_sp_session)
    allow(view).to receive(:current_sp).and_return(sp_with_logo)
  end

  it 'properly HTML escapes the secure notification' do
    render

    expect(rendered).to_not have_content('<strong>')
  end
end
