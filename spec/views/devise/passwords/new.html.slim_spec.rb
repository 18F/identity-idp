require 'rails_helper'

describe 'devise/passwords/new.html.slim' do
  before do
    @password_reset_email_form = PasswordResetEmailForm.new('')
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.passwords.forgot'))

    render
  end

  it 'has a localized header' do
    render

    expect(rendered).to have_selector('h1', text: t('headings.passwords.forgot'))
  end

  it 'sets form autocomplete to off' do
    render

    expect(rendered).to have_xpath("//form[@autocomplete='off']")
  end
end
