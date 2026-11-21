require 'rails_helper'

RSpec.describe 'two_factor_authentication/sms_opt_in/new.html.erb' do
  let(:phone) { '1-888-867-5309' }
  let(:phone_configuration) { build(:phone_configuration, phone: phone) }
  let(:phone_number_opt_out) { PhoneNumberOptOut.create_or_find_with_phone(phone) }
  let(:presenter) { TwoFactorAuthCode::SmsOptInPresenter.new }
  let(:cancel_url) { '/account' }
  let(:learn_more_path) do
    help_center_redirect_path(
      category: 'get-started',
      article: 'authentication-methods',
      flow: :two_factor_authentication,
      step: :sms_opt_in,
    )
  end

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    assign(:phone_configuration, phone_configuration)
    assign(:phone_number_opt_out, phone_number_opt_out)
    assign(:presenter, presenter)
    assign(:cancel_url, cancel_url)
    allow(view).to receive(:user_signing_up?).and_return(false)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('two_factor_authentication.opt_in.title'))

    render
  end

  context 'in the default layout' do
    it 'renders the masked phone number' do
      render

      expect(rendered).to have_content('(***) ***-5309')
    end

    it 'renders troubleshooting options' do
      render

      expect(rendered).to have_link(
        t('two_factor_authentication.login_options_link_text'),
        href: login_two_factor_options_path,
      )
      expect(rendered).to have_link(
        t('two_factor_authentication.learn_more'),
        href: learn_more_path,
      )
    end

    it 'does not render the NDS form-page card' do
      render

      expect(rendered).to_not have_selector('.auth--form-page')
    end
  end

  context 'in the NDS layout' do
    let(:opt_in_path) { login_two_factor_sms_opt_in_path(opt_out_uuid: phone_number_opt_out) }

    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the warning badge and heading' do
      render

      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('.auth__header .nds-status-icon.nds-status-icon--warning')
      expect(rendered).to have_css('h1', count: 1)
      expect(rendered).to have_css(
        '.auth__intro h1',
        text: t('two_factor_authentication.opt_in.title'),
      )
    end

    it 'renders the masked phone number and the mobile terms link' do
      render

      expect(rendered).to have_css('.auth__form-page-body hr.divider')
      expect(rendered).to have_css('.auth__form-page-body p strong', text: '(***) ***-5309')
      expect(rendered).to have_link(
        t('two_factor_authentication.mobile_terms_of_service'),
        href: MarketingSite.messaging_practices_url,
      )
    end

    it 'posts the send code action to the opt in path' do
      render

      expect(rendered).to have_css(
        ".auth__actions form[action='#{opt_in_path}'][method='post'] button.usa-button",
        text: t('forms.buttons.send_one_time_code'),
      )
    end

    it 'renders the troubleshooting options and the cancel link' do
      render

      expect(rendered).to have_css(
        '.auth__actions h2',
        text: t('components.troubleshooting_options.default_heading'),
      )
      expect(rendered).to have_css(
        ".auth__actions a.usa-button--tertiary[href='#{login_two_factor_options_path}']",
        text: t('two_factor_authentication.login_options_link_text'),
      )
      expect(rendered).to have_css(
        ".auth__actions a.usa-button--tertiary[href='#{learn_more_path}'][target='_blank']",
        text: t('two_factor_authentication.learn_more'),
      )
      expect(rendered).to have_css(
        ".auth__actions a.usa-button--tertiary[href='#{cancel_url}']",
        text: t('links.cancel'),
      )
    end

    context 'when the opt in request failed' do
      before { flash[:error] = t('two_factor_authentication.opt_in.error_retry') }

      it 'renders the error in the card' do
        render

        expect(rendered).to have_css(
          '.auth--form-page .usa-alert--error',
          text: t('two_factor_authentication.opt_in.error_retry'),
        )
      end
    end

    context 'when the user is signing up' do
      before { allow(view).to receive(:user_signing_up?).and_return(true) }

      it 'labels the cancel link for account creation without the legacy glyph' do
        render

        label = t('links.cancel_account_creation').delete_prefix('‹').strip
        expect(rendered).to have_css(
          ".auth__actions a.usa-button--tertiary[href='#{cancel_url}']",
          exact_text: label,
        )
        expect(rendered).not_to have_css('.auth__actions a', text: '‹')
      end
    end
  end
end
