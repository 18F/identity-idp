require 'rails_helper'

RSpec.describe 'idv/_no_sp_hardfail.html.slim' do
  it 'links to the profile' do
    render

    expect(rendered).to have_link(
      t('idv.messages.return_to_profile', app: APP_NAME),
      href: profile_path
    )
  end
end
