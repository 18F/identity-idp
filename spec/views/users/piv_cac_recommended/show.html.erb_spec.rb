require 'rails_helper'

RSpec.describe 'users/piv_cac_recommended/show.html.erb' do
  let(:user) { build(:user) }
  let(:profiling_enabled) { false }
  let(:threatmetrix_session_id) { 'ABCD-1234' }
  let(:threatmetrix_javascript_url) do
    'https://h.online-metrix.net/fp/tags.js?org_id=test_org_id&session_id=ABCD-1234'
  end
  let(:threatmetrix_iframe_url) do
    'https://h.online-metrix.net/fp/tags?org_id=test_org_id&session_id=ABCD-1234'
  end

  subject(:rendered) do
    render template: 'users/piv_cac_recommended/show', locals: {
      threatmetrix_session_id:,
      threatmetrix_javascript_urls: [threatmetrix_javascript_url],
      threatmetrix_iframe_url:,
    }
  end

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(FeatureManagement).to receive(:account_creation_device_profiling_collecting_enabled?)
      .and_return(profiling_enabled)
    assign(:recommended_presenter, PivCacRecommendedPresenter.new(user))
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.piv_cac_setup.upsell'))

    rendered
  end

  context 'in the default layout' do
    it 'renders the heading, copy and add/skip buttons' do
      expect(rendered).to have_css('h1', text: t('titles.piv_cac_setup.upsell'))
      expect(rendered).to have_content(t('two_factor_authentication.piv_cac_upsell.recommendation'))
      expect(rendered).to have_content(t('two_factor_authentication.piv_cac_upsell.explain'))
      expect(rendered).to have_css(
        "form[action='#{login_piv_cac_recommended_add_path}'][method=post] button",
        text: t('two_factor_authentication.piv_cac_upsell.add_piv'),
      )
      expect(rendered).to have_css(
        "form[action='#{login_piv_cac_recommended_skip_path}'][method=post] button",
        text: t('two_factor_authentication.piv_cac_upsell.choose_other_method'),
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

    it 'renders the form-page card with the info icon, heading, divider and copy' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('.auth__header--with-media .nds-status-icon svg.usa-icon')
      expect(rendered).to have_selector('h1', count: 1)
      expect(rendered).to have_selector(
        '.auth--form-page h1',
        text: t('titles.piv_cac_setup.upsell'),
      )
      expect(rendered).to have_css('.auth__form-page-body hr.divider')
      expect(rendered).to have_selector(
        '.auth__form-page-body .copy p',
        text: t('two_factor_authentication.piv_cac_upsell.recommendation'),
      )
      expect(rendered).to have_selector(
        '.auth__form-page-body .copy p',
        text: t('two_factor_authentication.piv_cac_upsell.explain'),
      )
    end

    it 'renders a primary add submit above a tertiary skip submit' do
      expect(rendered).to have_css('.auth__actions .actions form[method=post]', count: 2)
      add_form = ".actions form:nth-of-type(1)[action='#{login_piv_cac_recommended_add_path}']"
      skip_form = ".actions form:nth-of-type(2)[action='#{login_piv_cac_recommended_skip_path}']"
      expect(rendered).to have_css(
        "#{add_form} button.usa-button:not(.usa-button--tertiary)",
        text: t('two_factor_authentication.piv_cac_upsell.add_piv'),
      )
      expect(rendered).to have_css(
        "#{skip_form} button.usa-button--tertiary",
        text: t('two_factor_authentication.piv_cac_upsell.choose_other_method'),
      )
    end

    context 'when the user already has an MFA method' do
      let(:user) { build(:user, :with_phone) }

      it 'labels the skip submit "Skip"' do
        expect(rendered).to have_css(
          "form[action='#{login_piv_cac_recommended_skip_path}'] button.usa-button--tertiary",
          text: t('two_factor_authentication.piv_cac_upsell.skip'),
        )
        expect(rendered).to_not have_button(
          t('two_factor_authentication.piv_cac_upsell.choose_other_method'),
        )
      end
    end

    context 'when account creation device profiling is collecting' do
      let(:profiling_enabled) { true }

      it 'renders the ThreatMetrix profiling tags' do
        expect(rendered).to have_css(
          "script[src='#{threatmetrix_javascript_url}']",
          visible: :all,
        )
        expect(rendered).to have_css('noscript', visible: :all)
        expect(rendered).to include(threatmetrix_iframe_url.gsub('&', '&amp;'))
      end
    end

    context 'when account creation device profiling is off' do
      it 'does not render the ThreatMetrix profiling tags' do
        expect(rendered).to_not have_css('script[src*="online-metrix"]', visible: :all)
      end
    end
  end
end
