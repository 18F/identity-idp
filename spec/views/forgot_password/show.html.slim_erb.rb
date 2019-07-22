require 'rails_helper'

describe 'forgot_password/show.html.erb' do
  let(:email) { 'foo@bar.com' }

  before do
    @view_model = ForgotPasswordShow.new(resend: nil, session: { email: email })
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.verify_email'))

    render
  end

  it 'has a localized header' do
    render

    expect(rendered).to have_selector('h1', text: t('headings.verify_email'))
  end

  it 'contains link to resend the password reset email' do
    render

    expect(rendered).to have_button(t('links.resend'))
    expect(rendered).
      to have_xpath("//form[@action='#{user_password_path}']")
    expect(rendered).
      to have_xpath("//form[@method='post']")
  end

  it 'provides an explanation to the user' do
    render

    expect(rendered).to have_content t('notices.forgot_password.first_paragraph_start')
    expect(rendered).to have_content email
    expect(rendered).to have_content t('notices.forgot_password.first_paragraph_end')
    expect(rendered).to have_content t('notices.forgot_password.no_email_sent_explanation_start')
    expect(rendered).to have_content t('instructions.forgot_password.close_window')
    expect(rendered).to_not have_content t('notices.forgot_password.resend_email_success')
  end

  it 'contains a link to create a new account' do
    render

    expect(rendered).
      to have_link(t('notices.forgot_password.use_diff_email.link'), href: sign_up_email_path)
  end

  it 'displays a notice if resend_confirmation is present' do
    @view_model = ForgotPasswordShow.new(resend: true, session: {})

    render

    expect(view).to render_template(partial: 'forgot_password/_resend_alert')
  end
end
