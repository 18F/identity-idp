require 'rails_helper'

RSpec.describe 'users/second_mfa_reminder/new.html.erb' do
  subject(:rendered) { render }

  let(:sp_name) {}

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    decorated_sp_session = double
    allow(decorated_sp_session).to receive(:sp_name).and_return(sp_name)
    allow(view).to receive(:decorated_sp_session).and_return(decorated_sp_session)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('users.second_mfa_reminder.heading'))

    render
  end

  context 'in the default layout' do
    it 'renders with fallback app name for continue button' do
      expect(rendered).to have_button(t('users.second_mfa_reminder.continue', sp_name: APP_NAME))
    end

    context 'with sp name' do
      let(:sp_name) { 'Example SP' }

      it 'renders with sp name for continue button' do
        expect(rendered).to have_button(t('users.second_mfa_reminder.continue', sp_name:))
      end
    end

    it 'does not render the NDS form-page card' do
      expect(rendered).to_not have_selector('.auth--form-page')
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the info status icon, heading and description' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('.auth__header--with-media .nds-status-icon svg.usa-icon')
      expect(rendered).to have_selector(
        '.auth--form-page h1',
        text: t('users.second_mfa_reminder.heading'),
      )
      expect(rendered).to have_selector(
        '.auth__form-page-body .copy p',
        text: t('users.second_mfa_reminder.description'),
      )
    end

    it 'renders a primary add-method submit above a tertiary skip submit' do
      expect(rendered).to have_css(
        ".auth__actions .actions form[action='#{second_mfa_reminder_path}'][method=post]",
        count: 2,
      )
      expect(rendered).to have_css(
        '.actions form:nth-of-type(1) input[name=add_method][value=true]',
        visible: :all,
      )
      expect(rendered).to have_css(
        '.actions form:nth-of-type(1) button.usa-button:not(.usa-button--tertiary)',
        text: t('users.second_mfa_reminder.add_method'),
      )
      expect(rendered).to have_css(
        '.actions form:nth-of-type(2) button.usa-button--tertiary',
        text: t('nds.second_mfa_reminder.skip'),
      )
      expect(rendered).to_not have_css(
        '.actions form:nth-of-type(2) input[name=add_method]',
        visible: :all,
      )
    end

    context 'with sp name' do
      let(:sp_name) { 'Example SP' }

      it 'does not render the legacy continue-to-SP button' do
        expect(rendered).to_not have_button(t('users.second_mfa_reminder.continue', sp_name:))
      end
    end
  end
end
