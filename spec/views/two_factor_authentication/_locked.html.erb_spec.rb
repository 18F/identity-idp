require 'rails_helper'

RSpec.describe 'two_factor_authentication/_locked.html.erb' do
  include ActionView::Helpers::DateHelper

  let(:locked_at) { Time.zone.now }
  let(:user) { build(:user, second_factor_locked_at: locked_at) }
  let(:type) { 'otp_login_attempts' }
  let(:presenter) { TwoFactorAuthCode::MaxAttemptsReachedPresenter.new(type, user) }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.account_locked'))

    render('two_factor_authentication/locked', presenter:)
  end

  context 'in the default layout' do
    before do
      render('two_factor_authentication/locked', presenter:)
    end

    it 'renders the locked heading, reason and countdown timer', :freeze_time do
      expect(rendered).to have_css('h1', text: t('titles.account_locked'))
      expect(rendered).to have_content(
        t('two_factor_authentication.max_otp_login_attempts_reached'),
      )
      expect(rendered).to have_css(
        "p[role=timer][aria-live=polite] lg-countdown[data-expiration='#{
          user.lockout_time_expiration.iso8601
        }']",
      )
    end

    it 'renders the troubleshooting links in new tabs' do
      expect(rendered).to have_link(
        t('two_factor_authentication.read_about_two_factor_authentication'),
        href: help_center_redirect_url,
      )
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.contact_support', app_name: APP_NAME),
        href: contact_redirect_url,
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

    it 'renders the form-page card with the locked heading' do
      render('two_factor_authentication/locked', presenter:)

      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('.auth--form-page h1', text: t('titles.account_locked'))
      expect(rendered).to have_css('h1', count: 1)
    end

    it 'renders the error status-icon badge with the lock icon above the heading' do
      render('two_factor_authentication/locked', presenter:)

      expect(rendered).to have_css('.auth__header--with-media .nds-status-icon--error')
      expect(rendered).to have_css('.nds-status-icon--error .usa-icon')
      expect(rendered).to include(NDS::IconComponent.markup_for('nds/icons/lock/24.svg'))
    end

    it 'renders a divider above the lockout reason' do
      render('two_factor_authentication/locked', presenter:)

      expect(rendered).to have_css('.auth__form-page-body hr.divider')
      expect(rendered).to have_css(
        '.auth__form-page-body p',
        text: t('two_factor_authentication.max_otp_login_attempts_reached'),
      )
    end

    it 'renders the live countdown until the lockout expires', :freeze_time do
      render('two_factor_authentication/locked', presenter:)

      timer = Nokogiri::HTML(rendered).at_css('.auth__form-page-body p[role=timer]')
      expect(timer[:'aria-live']).to eq('polite')
      expect(timer[:'aria-atomic']).to eq('true')
      countdown = timer.at_css('strong lg-countdown')
      expect(countdown[:'data-expiration']).to eq(user.lockout_time_expiration.iso8601)
      expect(countdown[:'data-update-interval']).to eq(30.seconds.in_milliseconds.to_s)
      expect(countdown.text).to eq(
        distance_of_time_in_words(Time.zone.now, user.lockout_time_expiration, true),
      )
    end

    it 'renders the troubleshooting options as new-tab buttons' do
      render('two_factor_authentication/locked', presenter:)

      expect(rendered).to have_css(
        '.auth__actions .nds-troubleshooting-options h2',
        text: t('components.troubleshooting_options.default_heading'),
      )
      expect(rendered).to have_css(
        ".auth__actions a.usa-button[href='#{help_center_redirect_url}'][target=_blank]",
        text: t('two_factor_authentication.read_about_two_factor_authentication'),
      )
      expect(rendered).to have_css(
        ".auth__actions a.usa-button[href='#{contact_redirect_url}'][target=_blank]",
        text: t('idv.troubleshooting.options.contact_support', app_name: APP_NAME),
      )
    end

    it 'does not render the legacy status page' do
      render('two_factor_authentication/locked', presenter:)

      expect(rendered).to_not have_css('.alert-icon')
      expect(rendered).to_not have_css('.troubleshooting-options__options')
    end

    {
      'backup_code_login_attempts' => 'max_backup_code_login_attempts_reached',
      'generic_login_attempts' => 'max_generic_login_attempts_reached',
      'otp_requests' => 'max_otp_requests_reached',
      'totp_login_attempts' => 'max_otp_login_attempts_reached',
      'totp_requests' => 'max_otp_requests_reached',
      'personal_key_login_attempts' => 'max_personal_key_login_attempts_reached',
      'piv_cac_login_attempts' => 'max_piv_cac_login_attempts_reached',
    }.each do |lockout_type, key|
      context "when locked for #{lockout_type}" do
        let(:type) { lockout_type }

        it 'renders the matching lockout reason' do
          render('two_factor_authentication/locked', presenter:)

          expect(rendered).to have_css(
            '.auth__form-page-body p',
            text: t("two_factor_authentication.#{key}"),
          )
        end
      end
    end
  end
end
