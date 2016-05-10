require 'rails_helper'

describe 'devise/registrations/new.html.slim' do
  before do
    @register_user_email_form = RegisterUserEmailForm.new
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('upaya.titles.registrations.new'))

    render
  end

  it 'has a localized h2' do
    render

    expect(rendered).to have_selector('h2', text: t('upaya.headings.registrations.new'))
  end

  it 'sets form autocomplete to off' do
    render

    expect(rendered).to have_xpath("//form[@autocomplete='off']")
  end
end
