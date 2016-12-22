require 'rails_helper'

describe 'forgot_password/show.html.slim' do
  before do
    @email = 'foo@bar.com'
    @password_reset_email_form = PasswordResetEmailForm.new('foo@bar.com')
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
    expect(rendered).to have_content 'foo@bar.com'
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

  it 'displays a notice if @resend_confirmation is present' do
    @resend_confirmation = true

    render

    expect(rendered).to have_content t('notices.forgot_password.resend_email_success')
  end
end
