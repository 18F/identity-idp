require 'rails_helper'

describe 'devise/sessions/new.html.slim' do
  before do
    allow(view).to receive(:resource).and_return(build_stubbed(:user))
    allow(view).to receive(:resource_name).and_return(:user)
    allow(view).to receive(:devise_mapping).and_return(Devise.mappings[:user])
    allow(view).to receive(:controller_name).and_return('sessions')
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('upaya.titles.visitors.index', app_name: APP_NAME))

    render
  end

  it 'has a localized h2 headings' do
    render

    expect(rendered).to have_selector('h2', text: t('upaya.headings.log_in'))
  end

  it 'has proper css classes for log in / sign up nav' do
    render

    base_class = 'btn btn-primary border-box col-12 center'

    sign_up_class = "#{base_class} bg-gray"
    expect(rendered).
      to have_xpath("//a[@class='#{sign_up_class}' and @href='#{new_user_registration_path}']")

    log_in_class = "#{base_class} bg-navy"
    expect(rendered).
      to have_xpath("//a[@class='#{log_in_class}' and @href='#{new_user_session_path}']")
  end

  it 'includes a link to create a new account' do
    render

    expect(rendered).
      to have_link(
        t('upaya.links.sign_up'), href: new_user_registration_path
      )
  end
end
