require 'rails_helper'

RSpec.describe 'idv/_hardfail4.html.slim' do
  let(:decorated_session) do
    instance_double('SessionDecorator', sp_name: 'Example SP', sp_return_url: 'test.host')
  end

  before do
    allow(view).to receive(:decorated_session).and_return(decorated_session)
  end

  it 'links to the profile' do
    render

    expect(rendered).to have_link(
      t('idv.messages.return_to_profile', app: APP_NAME),
      href: profile_path
    )
  end
end
