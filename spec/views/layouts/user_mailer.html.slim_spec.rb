require 'rails_helper'

describe 'layouts/user_mailer.html.slim' do
  before do
    @mail = UserMailer.email_added('foo@example.com')
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

  it 'includes the message subject in the body' do
    expect(rendered).to have_content @mail.subject
  end

  it 'includes a request to not reply to this messsage' do
    expect(rendered).to have_content(t('mailer.no_reply'))
  end

  it 'includes the support text and link' do
    expect(rendered).to have_content(t('mailer.no_reply'))
    expect(rendered).to have_content(
      t('mailer.help', app: APP_NAME, link: MarketingSite.nice_help_url),
    )
    expect(rendered).to have_link(MarketingSite.nice_help_url, href: MarketingSite.help_url)
  end

  it 'includes link to About login.gov' do
    expect(rendered).to have_link(t('mailer.about', app: APP_NAME), href: MarketingSite.base_url)
  end

  it 'includes link to the privacy policy' do
    expect(rendered).to have_link(t('mailer.privacy_policy'), href: MarketingSite.privacy_url)
  end
end
