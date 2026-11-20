require 'rails_helper'

RSpec.describe 'users/sts_consent_revoke/show.html.erb' do
  let(:consent) { create(:user_consent_sts, created_at: Time.zone.parse('2026-11-02 15:00 UTC')) }
  let(:page) { Capybara.string(rendered) }

  before do
    allow(IdentityConfig.store).to receive(:sts_consent_expiration_in_days).and_return(365)
    allow(view).to receive(:nds_layout?).and_return(false)
    @consent = consent
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.revoke_consent'))

    render
  end

  context 'in the default layout' do
    it 'renders the legacy heading, description and actions' do
      render

      expect(page).to have_css('h1', text: t('titles.revoke_consent'))
      expect(page).to have_content(
        t('account.connected_delegation.disconnect', america_gov_name: AMERICA_GOV_NAME),
      )
      expect(page).to have_css(
        "form[action='#{sts_consent_revoke_url(id: consent.id)}'] [name=_method][value=delete]",
        visible: :all,
      )
      expect(page).to have_button(t('forms.buttons.continue'))
      expect(page).to have_link(t('links.cancel'), href: account_connected_services_path)
    end

    it 'does not render the NDS form page' do
      render

      expect(page).not_to have_css('.auth--form-page')
    end
  end

  context 'in the NDS layout' do
    before { allow(view).to receive(:nds_layout?).and_return(true) }

    it 'asks for the signed-in header' do
      render

      expect(view.content_for(:nds_account_header)).to eq('true')
    end

    it 'renders the service name, its seal and when the consent expires' do
      render

      expect(page).to have_css('h1', count: 1)
      expect(page).to have_css('.auth--form-page h1', text: 'MyTravelGov')
      expect(page).to have_css(
        ".auth__header img.agency-seal.agency-seal--100[alt=''][src*='DOS']",
      )
      expect(page).to have_css(
        '.auth__intro-description',
        text: t('nds.dashboard_home.delegation_expires', date: 'November 2, 2027'),
      )
    end

    it 'links to the service in a new tab' do
      render

      expect(page).to have_css(
        "a.usa-link--external[href='https://mytravel.state.gov/'][target=_blank]",
        text: t('nds.otp_verification.learn_more'),
      )
    end

    it 'renders the destructive disconnect button deleting the same consent' do
      render

      form = page.find("form[action='#{sts_consent_revoke_url(id: consent.id)}']")
      expect(form).to have_css('[name=_method][value=delete]', visible: :all)
      expect(form).to have_button(
        t('account.revoke_consent.link_title'),
        class: %w[usa-button usa-button--danger],
      )
    end

    it 'renders a secondary cancel button back to the connected services page' do
      render

      expect(page).to have_link(
        t('links.cancel'),
        href: account_connected_services_path,
        class: %w[usa-button usa-button--secondary],
      )
      expect(page).not_to have_content(
        t('account.connected_delegation.disconnect', america_gov_name: AMERICA_GOV_NAME),
      )
    end
  end
end
