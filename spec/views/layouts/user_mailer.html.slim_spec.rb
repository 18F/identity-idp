require 'rails_helper'

describe 'layouts/user_mailer.html.slim' do
  before do
    @mail = UserMailer.email_changed('foo@example.com')
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
      t('mailer.help', app: APP_NAME, link: MarketingSite.contact_url)
    )
    expect(rendered).to have_link(MarketingSite.contact_url, href: MarketingSite.contact_url)
  end

  it 'includes placeholder link to About login.gov' do
    expect(rendered).to have_link("About #{APP_NAME}", href: '#')
  end

  it 'includes placeholder link to the privacy policy' do
    expect(rendered).to have_link('Privacy policy', href: '#')
  end
end
