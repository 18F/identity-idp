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

  it 'has a localized h2' do
    render

    expect(rendered).to have_selector('h2', text: t('upaya.headings.registrations.new'))
  end

  it 'has proper css classes for log in / sign up nav' do
    render

    base_class = 'btn btn-primary border-box col-12 center'

    sign_up_class = "#{base_class} bg-navy"
    expect(rendered).
      to have_xpath("//a[@class='#{sign_up_class}' and @href='#{new_user_registration_path}']")

    log_in_class = "#{base_class} bg-gray"
    expect(rendered).
      to have_xpath("//a[@class='#{log_in_class}' and @href='#{new_user_session_path}']")
  end

  it 'sets form autocomplete to off' do
    render

    expect(rendered).to have_xpath("//form[@autocomplete='off']")
  end
end
