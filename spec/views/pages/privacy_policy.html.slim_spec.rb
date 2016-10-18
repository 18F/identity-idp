require 'rails_helper'

describe 'pages/privacy_policy.html.slim' do
  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.privacy_policy'))

    render
  end

  it 'includes a link to create a new account' do
    render

    expect(rendered).
      to have_link(t('links.create_account'), href: new_user_registration_path)
  end
end
