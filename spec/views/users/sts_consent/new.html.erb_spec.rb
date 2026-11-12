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
      t('sts_consent.cancel_and_return'),
      href: sts_consent_cancel_path,
    )
  end
end
