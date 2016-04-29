require 'rails_helper'

describe 'devise/sessions/new.html.slim' do
  before do
    allow(view).to receive(:resource).and_return(build_stubbed(:user))
    allow(view).to receive(:resource_name).and_return(:user)
    allow(view).to receive(:devise_mapping).and_return(Devise.mappings[:user])
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('upaya.titles.visitors.index'))

    render
  end

  it 'has a localized h2 headings' do
    render

    expect(rendered).to have_selector('h2', t('upaya.headings.log_in'))
    expect(rendered).
      to have_selector('h2', t('upaya.headings.visitors.new_account'))
  end

  it 'includes a link to create a new account' do
    render

    expect(rendered).
      to have_link('create an account', href: new_user_registration_path)
  end
end
