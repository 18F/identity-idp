require 'rails_helper'

describe 'sign_up/registrations/new.html.slim' do
  before do
    @register_user_email_form = RegisterUserEmailForm.new
    allow(view).to receive(:controller_name).and_return('registrations')
    allow(view).to receive(:current_user).and_return(nil)
    allow(view).to receive(:session).and_return(sign_up_init: true)
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.registrations.new'))

    render
  end

  it 'includes a link to terms of service' do
    render

    expect(rendered).
      to have_link(t('notices.terms_of_service.link'), href: MarketingSite.privacy_url)

    expect(rendered).to have_selector("a[href='#{MarketingSite.privacy_url}'][target='_blank']")
  end

  it 'sets form autocomplete to off' do
    render

    expect(rendered).to have_xpath("//form[@autocomplete='off']")
  end

  it 'includes a form to cancel account creation' do
    render
    link = t('links.cancel_account_creation')

    expect(rendered).to have_selector("input[value='#{link}']")
  end
end
