require 'rails_helper'

RSpec.describe 'forgot_password/show.html.erb' do
  let(:email) { 'foo@bar.com' }

  before do
    @email = email
    @password_reset_email_form = PasswordResetEmailForm.new(email)
    @resend = nil
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.verify_email'))

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

  it 'displays a notice if resend_confirmation is present' do
    @resend = true

    render

    expect(view).to render_template(partial: 'forgot_password/_resend_alert')
  end
end
