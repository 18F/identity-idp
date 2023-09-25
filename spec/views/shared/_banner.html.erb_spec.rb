require 'rails_helper'

RSpec.describe 'shared/_banner.html.erb' do
  before do
    sp_with_logo = build_stubbed(
      :service_provider, logo: 'generic.svg', friendly_name: 'Best SP ever'
    )

    decorated_sp_session = ServiceProviderSession.new(
      sp: sp_with_logo,
      view_context: '',
      sp_session: {},
      service_provider_request: nil,
    )
    allow(view).to receive(:decorated_sp_session).and_return(decorated_sp_session)
  end

  it 'properly HTML escapes the secure notification' do
    render

    expect(rendered).to_not have_content('<strong>')
  end
end
