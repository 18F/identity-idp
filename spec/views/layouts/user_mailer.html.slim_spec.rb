require 'rails_helper'

describe 'layouts/user_mailer.html.slim' do
  before do
    @mail = UserMailer.email_changed('foo@example.com')
    allow(view).to receive(:message).and_return(@mail)

    render
  end

  it 'includes the message subject as the title' do
    expect(rendered).to have_title @mail.subject
  end

  it 'includes the app logo' do
    expect(rendered).to have_css("img[src*='logo']")
  end

  it 'includes the message subject in the body' do
    expect(rendered).to have_content @mail.subject
  end

  it 'includes a request to not reply to this messsage' do
    expect(rendered).to have_content 'Please do not reply to this message.'
  end

  it 'includes the support text and link' do
    expect(rendered).
      to have_content(
        'For more help, please contact the Login.gov Customer Contact Center via web form at'
      )
    expect(rendered).to have_link(Figaro.env.support_url, href: Figaro.env.support_url)
  end

  it 'includes placeholder link to About login.gov' do
    expect(rendered).to have_link("About #{APP_NAME}", href: '#')
  end

  it 'includes placeholder link to the privacy policy' do
    expect(rendered).to have_link('Privacy policy', href: '#')
  end
end
