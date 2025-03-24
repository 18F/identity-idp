require 'rails_helper'

RSpec.describe 'layouts/mailer.html.erb' do
  let(:user) { build_stubbed(:user) }

  before do
    @mail = UserMailer.with(user: user, email_address: user.email_addresses.first).email_added
    allow(view).to receive(:message).and_return(@mail)
    allow(view).to receive(:attachments).and_return(@mail.attachments)

    render
  end

  it 'includes the message subject as the title' do
    expect(rendered).to have_title @mail.subject
  end

  it 'includes the app logo' do
    expect(rendered).to have_css("img[src*='.mail']")
  end

  it 'includes alt text for app logo that reads Login.gov logo' do
    expect(rendered).to have_css("img[alt='#{t('mailer.logo', app_name: APP_NAME)}']")
  end

  it 'includes the message subject in the body' do
    expect(rendered).to have_content @mail.subject
  end

  it 'includes a request to not reply to this messsage' do
    expect(rendered).to have_content(t('mailer.no_reply'))
  end

  it 'includes the support text and link' do
    expect(rendered).to have_content(t('mailer.no_reply'))
    expect(rendered).to have_content(
      t('mailer.help_html', app_name: APP_NAME, link_html: MarketingSite.nice_help_url),
    )
    expect(rendered).to have_link(MarketingSite.nice_help_url, href: MarketingSite.help_url)
  end

  it 'includes link to About Login.gov' do
    expect(rendered).to have_link(
      t('mailer.about', app_name: APP_NAME),
      href: MarketingSite.base_url,
    )
  end

  it 'includes link to the privacy policy' do
    expect(rendered).to have_link(
      t('mailer.privacy_policy'),
      href: MarketingSite.security_and_privacy_practices_url,
    )
  end

  context 'in-person proofing ready to verify emails' do
    let(:user) { create(:user, :with_pending_in_person_enrollment) }
    let(:enrollment) { create(:in_person_enrollment, :pending, :with_service_provider) }
    let(:sp_name) { 'Friendly Service Provider' }
    let(:logo_is_png) { true }
    let(:sp_logo_url) { '/assets/sp-logos/gsa.png' }

    before do
      @mail = UserMailer.with(
        user: user,
        email_address: user.email_addresses.first,
      ).in_person_ready_to_verify(enrollment:, is_enhanced_ipp: false, logo_is_png:, sp_logo_url:)
      allow(view).to receive(:message).and_return(@mail)
      allow(view).to receive(:attachments).and_return(@mail.attachments)
      @sp_name = sp_name
      @logo_is_png = logo_is_png
      @sp_logo_url = sp_logo_url

      render
    end

    context 'when the partner agency logo is a png' do
      it 'displays the partner agency logo' do
        expect(rendered).to have_css("img[src*='gsa.png']")
      end
    end

    context 'when the partner agency logo is a svg' do
      let(:logo_is_png) { false }
      let(:sp_logo_url) { '/assets/sp-logos/generic.svg' }

      it 'displays the partner agency name' do
        expect(rendered).to have_content(sp_name)
      end
    end

    context 'when there is no partner agency logo' do
      let(:logo_is_png) { false }
      let(:sp_logo_url) { nil }

      it 'displays the partner agency name' do
        expect(rendered).to have_content('Friendly Service Provider')
      end
    end
  end
end
