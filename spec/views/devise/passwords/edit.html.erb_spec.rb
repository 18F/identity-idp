require 'rails_helper'

describe 'devise/passwords/edit.html.erb' do
  before do
    user = build_stubbed(:user, :signed_up)
    @reset_password_form = ResetPasswordForm.new(user)
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.passwords.change'))

    render
  end

  it 'has a localized header' do
    render

    expect(rendered).to have_selector('h1', text: t('headings.passwords.change'))
  end

  it 'sets form autocomplete to off' do
    render

    expect(rendered).to have_xpath("//form[@autocomplete='off']")
  end

  it 'has information about the password key' do
    render

    expect(rendered).to have_selector('p', text: t('instructions.password.password_key'))
  end
end
