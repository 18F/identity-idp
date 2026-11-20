require 'rails_helper'

RSpec.describe 'users/verify_password/new.html.erb' do
  let(:user) { build_stubbed(:user, :fully_registered) }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:current_user).and_return(user)
  end

  it 'has the legacy localized title in the default layout' do
    expect(view).to receive(:title=).with(t('idv.titles.enter_password'))

    render
  end

  context 'in the default layout' do
    before { render }

    it 'renders the password form' do
      expect(rendered).to have_css(
        'h1',
        text: t('idv.titles.session.enter_password', app_name: APP_NAME),
      )
      expect(rendered).to have_css(
        "form[action='#{update_verify_password_path}'] input[name='user[password]']",
      )
    end

    it 'does not render the NDS form-page card' do
      expect(rendered).to_not have_selector('.auth--form-page')
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'has a title matching the password heading' do
      expect(view).to receive(:title=).with(t('nds.verify_password.heading'))

      render
    end

    it 'renders the form-page card with the heading and message' do
      render

      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('.auth--form-page h1', text: t('nds.verify_password.heading'))
      expect(rendered).to have_css('h1', count: 1)
      expect(rendered).to have_css(
        '.auth__intro-description',
        text: t('idv.messages.sessions.enter_password_message', app_name: APP_NAME),
      )
    end

    it 'puts the same user[password] field to the verify password path' do
      render

      form = Nokogiri::HTML(rendered).at_css(
        "form[action='#{update_verify_password_path}'][data-nds-submit-gate]",
      )
      expect(form).to be_present
      expect(form.at_css('input[name="_method"]')[:value]).to eq('put')
      input = form.at_css('input[name="user[password]"][type=password]')
      expect(input[:required]).to be_present
      expect(input[:autocomplete]).to eq('current-password')
      expect(form.at_css("label[for='#{input[:id]}']").text).to include(t('idv.form.password'))
      expect(form.at_css('.usa-input__toggle')).to be_present
      expect(form.at_css('.auth__actions button[type=submit]').text)
        .to include(t('forms.buttons.continue'))
    end

    it 'renders an incorrect password error in the card' do
      flash[:error] = t('errors.messages.password_incorrect')

      render

      expect(rendered).to have_css(
        '.auth--form-page .usa-alert--error',
        text: t('errors.messages.password_incorrect'),
      )
    end
  end
end
