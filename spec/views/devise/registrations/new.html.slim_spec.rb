require 'rails_helper'

describe 'devise/registrations/new.html.slim' do
  before do
    @register_user_email_form = RegisterUserEmailForm.new
    allow(view).to receive(:controller_name).and_return('registrations')
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('upaya.titles.registrations.new'))

    render
  end

  it 'has proper css classes for log in / sign up nav' do
    render

    expect(rendered).to have_xpath(
      "//a[@class='btn-auth btn-auth--active' and @href='#{new_user_registration_path}']"
    )

    expect(rendered).to have_xpath(
      "//a[@class='btn-auth' and @href='#{new_user_session_path}']"
    )
  end

  it 'sets form autocomplete to off' do
    render

    expect(rendered).to have_xpath("//form[@autocomplete='off']")
  end
end
