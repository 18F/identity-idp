require 'rails_helper'

RSpec.describe 'two_factor_authentication/sms_opt_in/error.html.erb' do
  let(:phone_configuration) { build(:phone_configuration, phone: '1 888-867-5309') }
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
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
      render
    end

    it 'renders the form-page card with the error badge and heading' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('.auth__header .nds-status-icon.nds-status-icon--error')
      expect(rendered).to have_css('h1', count: 1)
      expect(rendered).to have_css(
        '.auth__intro h1',
        text: t('two_factor_authentication.opt_in.title'),
      )
    end

    it 'renders the masked phone number and the 30-day wait' do
      expect(rendered).to have_css('.auth__form-page-body hr.divider')
      expect(rendered).to have_css('.auth__form-page-body p strong', text: '(***) ***-5309')
      expect(rendered).to have_css(
        '.auth__form-page-body p',
        text: t('two_factor_authentication.opt_in.wait_30d_opt_in'),
      )
    end

    it 'does not offer to send a code' do
      expect(rendered).not_to have_content(t('forms.buttons.send_one_time_code'))
    end

    it 'renders the troubleshooting options and the cancel link' do
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
  end
end
