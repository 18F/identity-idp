require 'rails_helper'

describe 'devise/registrations/start.html.slim' do
  it 'has a localized title' do
    expect(view).to receive(:title).with(t('upaya.titles.registrations.start'))

    render
  end

  it 'includes a link to create a new account' do
    render

    expect(rendered).
      to have_link(t('upaya.links.get_started'), href: new_user_registration_path)
  end
end
