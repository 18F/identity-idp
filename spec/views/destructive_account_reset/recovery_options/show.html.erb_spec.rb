require 'rails_helper'

RSpec.describe 'destructive_account_reset/recovery_options/show.html.erb' do
  before do
    allow(view).to receive(:nds_layout?).and_return(false)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('destructive_account_reset.recovery_options.header'))

    render
  end

  it 'has button to cancel request' do
    render
    expect(rendered).to have_button t('destructive_account_reset.request.no_cancel')
  end

  it 'does not render the NDS form-page card' do
    render
    expect(rendered).not_to have_selector('.auth--form-page')
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
      render
    end

    it 'renders the form-page heading and help text' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('h1', count: 1)
      expect(rendered).to have_css(
        '.auth__intro h1',
        text: t('destructive_account_reset.recovery_options.header'),
      )
      expect(rendered).to have_css(
        '.auth__intro-description',
        text: t('destructive_account_reset.recovery_options.help_text', app_name: APP_NAME),
      )
    end

    it 'renders the three recovery steps as a process list' do
      expect(rendered).to have_css('.auth__form-page-body .usa-process-list__item', count: 3)
      expect(rendered).to have_link(
        t('destructive_account_reset.recovery_options.try_method_description_link'),
        href: login_two_factor_options_path,
      )
      expect(rendered).to have_link(
        t('destructive_account_reset.recovery_options.check_webauthn_platform_help_link'),
        href: MarketingSite.help_center_article_url(
          category: 'trouble-signing-in',
          article: 'face-or-touch-unlock',
        ),
      )
    end

    it 'links to the account reset request to delete the account' do
      expect(rendered).to have_css(
        ".auth__actions a.usa-button[href='#{account_reset_request_path}']",
        text: t('destructive_account_reset.recover_options.yes_delete'),
      )
    end

    it 'posts to the recovery options cancel path from a tertiary button' do
      expect(rendered).to have_css(
        ".auth__actions form[action='#{account_reset_recovery_options_cancel_path}'] " \
          "button.usa-button--tertiary",
        text: t('destructive_account_reset.request.no_cancel'),
      )
    end

    it 'does not render the legacy still-not-working prompt' do
      expect(rendered).not_to have_content(
        t('destructive_account_reset.recovery_options.still_working'),
      )
    end
  end
end
