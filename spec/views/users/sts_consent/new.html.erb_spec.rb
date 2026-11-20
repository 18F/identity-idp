require 'rails_helper'

RSpec.describe 'users/sts_consent/new.html.erb' do
  let(:user) { build_stubbed(:user, :fully_registered) }
  let(:target_app) { 'urn:gov:gsa:openidconnect:sp:broker' }
  let(:actor_app) { 'urn:gov:gsa:openidconnect:sp:target' }

  before do
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:nds_layout?).and_return(false)
    @sts_consent_form = StsConsentForm.new(user: user, target_app: target_app, actor_app: actor_app)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=)
      .with(t('titles.sts_consent', america_gov_name: AMERICA_GOV_NAME))

    render
  end

  it 'displays the heading and content' do
    render

    expect(rendered).to have_css(
      'h1.page-heading',
      text: t('sts_consent.heading', america_gov_name: AMERICA_GOV_NAME),
    )
    expect(rendered).to have_content(
      t('sts_consent.content', america_gov_name: AMERICA_GOV_NAME),
    )
  end

  it 'links to MyTravelGov in a new tab' do
    render

    expect(rendered).to have_css(
      ".usa-accordion__content a[href='https://mytravel.state.gov/s/'][target='_blank']",
      text: t('sts_consent.learn_more'),
    )
  end

  it 'submits consent with the allow and continue button' do
    render

    expect(rendered).to have_css("form[action='#{sts_consent_path}']")
    expect(rendered).to have_css(
      "input[type=hidden][name='sts_consent_form[consent_given]']" \
      "[value='#{StsConsentForm::CONSENT_GIVEN_VALUE}']",
      visible: :all,
    )
    expect(rendered).to have_button(t('sts_consent.allow_and_continue'))
  end

  it 'links to the sts consent cancel flow' do
    render

    expect(rendered).to have_link(
      t('sts_consent.cancel_and_return', america_gov_name: AMERICA_GOV_NAME),
      href: sts_consent_cancel_path,
    )
  end

  it 'does not render the NDS consent rows in the default layout' do
    render

    expect(rendered).not_to have_css('.consent-service')
    expect(rendered).not_to have_content(
      t('nds.sts_consent.heading', america_gov_name: AMERICA_GOV_NAME),
    )
  end

  context 'in the NDS layout' do
    before { allow(view).to receive(:nds_layout?).and_return(true) }

    it 'renders the heading and description' do
      render

      expect(rendered).to have_css(
        'h1',
        text: t('nds.sts_consent.heading', america_gov_name: AMERICA_GOV_NAME),
      )
      expect(rendered).to have_content(
        t('nds.sts_consent.description', america_gov_name: AMERICA_GOV_NAME, app_name: APP_NAME),
      )
      expect(rendered).not_to have_css('.usa-accordion')
    end

    it 'renders a collapsed consent row for the agency service' do
      render

      expect(rendered).to have_css(
        '.consent ul.consent__services > li > details.consent-service:not([open])',
      )
      expect(rendered).to have_css(
        'summary.consent-service__summary .consent-service__title',
        text: t('nds.sts_consent.agency_name'),
      )
      expect(rendered).to have_css(
        'summary.consent-service__summary .consent-service__description',
        text: t('nds.sts_consent.agency_description'),
      )
      expect(rendered).to have_css('summary img.agency-seal[alt=""]')
      expect(rendered).to have_css('summary svg.consent-service__chevron[aria-hidden="true"]')
    end

    it 'lists what is shared inside the row' do
      render

      details = Capybara.string(rendered).find('.consent-service__details', visible: :all)
      expect(details).to have_css(
        'h2.consent-service__label',
        text: t('sts_consent.about_heading'),
        visible: :all,
      )
      expect(details).to have_content(t('nds.sts_consent.about_description'), normalize_ws: true)
      expect(details).to have_css(
        'h2.consent-service__label',
        text: t('nds.sts_consent.permissions_heading', america_gov_name: AMERICA_GOV_NAME),
        visible: :all,
      )
      expect(details).to have_content(t('nds.sts_consent.permissions_description'))
      expect(details).to have_css(
        'h2.consent-service__label',
        text: t('nds.sts_consent.shared_information_heading', america_gov_name: AMERICA_GOV_NAME),
        visible: :all,
      )
      expect(details).to have_content(t('nds.sts_consent.shared_information_description'))
    end

    it 'links to MyTravelGov in a new tab' do
      render

      expect(rendered).to have_css(
        ".consent-service__details a.consent-service__link[href='https://mytravel.state.gov/s/']" \
        "[target='_blank']",
        text: t('nds.otp_verification.learn_more'),
        visible: :all,
      )
    end

    it 'submits consent with the allow button' do
      render

      expect(rendered).to have_css("form[action='#{sts_consent_path}'][method='post']")
      expect(rendered).to have_css(
        "form input[type=hidden][name='sts_consent_form[consent_given]']" \
        "[value='#{StsConsentForm::CONSENT_GIVEN_VALUE}']",
        visible: :all,
      )
      expect(rendered).to have_css(
        "form button[type='submit'].usa-button:not(.usa-button--tertiary)",
        text: t('nds.sts_consent.allow'),
      )
      expect(rendered).not_to have_button(t('sts_consent.allow_and_continue'))
    end

    it 'links to the sts consent cancel flow as a tertiary button' do
      render

      expect(rendered).to have_css(
        "a.usa-button.usa-button--tertiary[href='#{sts_consent_cancel_path}']",
        text: t('sts_consent.cancel_and_return', america_gov_name: AMERICA_GOV_NAME),
      )
    end
  end
end
