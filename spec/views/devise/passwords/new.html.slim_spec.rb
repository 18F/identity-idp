require 'rails_helper'

describe 'devise/passwords/new.html.slim' do
  let(:user) { build_stubbed(:user) }

  before do
    @password_reset_email_form = PasswordResetEmailForm.new('')

    allow(view).to receive(:current_user).and_return(user)
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.passwords.forgot'))

    render
  end

  context 'localized header' do
    it 'displays the basic header' do
      render

      expect(rendered).to have_selector('h1', text: t('headings.passwords.forgot.basic'))
    end

    it 'displays LOA3 header during LOA3 flow' do
      allow(view).to receive(:loa3_requested?).and_return(true)
      render
      expect(rendered).to have_selector('h1', text: t('headings.passwords.forgot.loa3'))
    end
  end

  it 'sets form autocomplete to off' do
    render

    expect(rendered).to have_xpath("//form[@autocomplete='off']")
  end
end
