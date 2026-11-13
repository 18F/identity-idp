require 'rails_helper'

RSpec.describe 'users/authorization_confirmation/new.html.erb' do
  let(:email) { 'user@example.com' }
  let(:sp_name) { 'Example Service Provider' }
  let(:decorated_sp_session) do
    instance_double(ServiceProviderSession, sp_name:, new_session_heading: 'SP heading')
  end
  let(:current_sp) { nil }

  before do
    assign(:email, email)
    allow(view).to receive(:decorated_sp_session).and_return(decorated_sp_session)
    allow(view).to receive(:current_sp).and_return(current_sp)
    allow(view).to receive(:nds_layout?).and_return(false)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.sign_up.confirmation'))

    render
  end

  context 'in the default layout' do
    it 'renders the SP registration heading' do
      render

      expect(rendered).to have_css('h2', text: sp_name)
    end

    context 'without a service provider name' do
      let(:sp_name) { nil }

      it 'renders the new session heading' do
        render

        expect(rendered).to have_css('h1', text: 'SP heading')
      end
    end

    it 'shows the signed-in email' do
      render

      expect(rendered).to have_content(t('user_authorization_confirmation.currently_logged_in'))
      expect(rendered).to have_content(email)
    end

    it 'renders the continue and switch-email buttons' do
      render

      expect(rendered).to have_css(
        "form[action='#{user_authorization_confirmation_path}'][method='post']",
      )
      expect(rendered).to have_button(t('user_authorization_confirmation.continue'))
      expect(rendered).to have_css(
        "form[action='#{reset_user_authorization_path}'] input[name='_method'][value='delete']",
        visible: :all,
      )
      expect(rendered).to have_button(t('user_authorization_confirmation.sign_in'))
    end

    it 'does not render the NDS form-page card' do
      render

      expect(rendered).to_not have_selector('.auth--form-page')
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the SP heading and subtitle' do
      render

      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_selector('h1', count: 1)
      expect(rendered).to have_selector('h1', text: t('headings.sign_in_with_sp', sp: sp_name))
      expect(rendered).to have_selector('.auth__intro-description strong', text: sp_name)
      expect(rendered).to have_selector(
        '.auth__intro-description',
        text: t('headings.create_account_with_sp.sp_text', app_name: APP_NAME),
      )
    end

    it 'shows the signed-in email in the summary card' do
      render

      expect(rendered).to have_selector(
        '.auth__form-page-body .card',
        text: t('user_authorization_confirmation.currently_logged_in'),
      )
      expect(rendered).to have_selector(
        '.nds-summary dt.nds-summary__label',
        text: t('help_text.requested_attributes.email'),
      )
      expect(rendered).to have_selector('.nds-summary dd.nds-summary__value', text: email)
    end

    it 'renders continue and switch-email actions on the same paths and methods' do
      render

      expect(rendered).to have_selector(
        ".auth__actions form[action='#{user_authorization_confirmation_path}'][method='post'] " \
          "button.usa-button",
        text: t('user_authorization_confirmation.continue'),
      )
      expect(rendered).to have_selector(
        '.auth__actions .separator',
        text: t('user_authorization_confirmation.or'),
      )
      expect(rendered).to have_selector(
        ".auth__actions form[action='#{reset_user_authorization_path}'] " \
          "input[name='_method'][value='delete']",
        visible: :all,
      )
      expect(rendered).to have_selector(
        ".auth__actions form[action='#{reset_user_authorization_path}'] " \
          "button.usa-button.usa-button--secondary",
        text: t('user_authorization_confirmation.sign_in'),
      )
    end

    it 'does not render the legacy SP registration heading' do
      render

      expect(rendered).to_not have_css('h2')
      expect(rendered).to_not have_css('img[src*="user-access"]')
    end

    it 'does not render a logo when the service provider has none' do
      render

      expect(rendered).to_not have_selector('.auth__media')
    end

    context 'with a service provider logo' do
      let(:current_sp) { build(:service_provider, logo: 'generic.svg') }

      it 'renders the logo as media with the SP name as alt text' do
        render

        expect(rendered).to have_selector(
          "img.auth__media[alt='#{sp_name}'][src*='generic']",
        )
      end
    end

    context 'without a service provider name' do
      let(:sp_name) { nil }

      it 'renders the generic sign-in heading without a subtitle' do
        render

        expect(rendered).to have_selector('h1', text: t('headings.sign_in_without_sp'))
        expect(rendered).to_not have_selector('.auth__intro-description')
      end
    end
  end
end
