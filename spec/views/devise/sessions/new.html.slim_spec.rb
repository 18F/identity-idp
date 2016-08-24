require 'rails_helper'

describe 'devise/sessions/new.html.slim' do
  before do
    allow(view).to receive(:resource).and_return(build_stubbed(:user))
    allow(view).to receive(:resource_name).and_return(:user)
    allow(view).to receive(:devise_mapping).and_return(Devise.mappings[:user])
    allow(view).to receive(:controller_name).and_return('sessions')
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.visitors.index'))

    render
  end

  it 'has proper css classes for log in / sign up nav' do
    render

    expect(rendered).
      to have_xpath("//a[@class='btn-auth' and @href='#{new_user_start_path}']")

    expect(rendered).
      to have_xpath(
        "//a[@class='btn-auth btn-auth--active' and @href='#{new_user_session_path}']"
      )
  end

  it 'includes a link to create a new account' do
    render

    expect(rendered).
      to have_link(
        t('links.sign_up'), href: new_user_start_path
      )
  end
end
