require 'rails_helper'

RSpec.describe 'forgot_password/show.html.erb' do
  let(:email) { 'foo@bar.com' }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    @email = email
    @password_reset_email_form = PasswordResetEmailForm.new(email)
    @resend = nil
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.verify_email'))

    render
  end

  context 'in the default layout' do
    it 'has a localized header' do
      render

      expect(rendered).to have_selector('h1', text: t('headings.verify_email'))
    end

    it 'contains link to resend the password reset email' do
      render

      expect(rendered).to have_button(t('links.resend'))
      expect(rendered)
        .to have_xpath("//form[@action='#{user_password_path}']")
      expect(rendered)
        .to have_xpath("//form[@method='post']")
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

    it 'does not render the NDS form-page card' do
      render

      expect(rendered).to_not have_selector('.auth--form-page')
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the check-your-email heading' do
      render

      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('.auth--form-page h1', text: t('headings.verify_email'))
    end

    it 'names the email address in the intro' do
      render

      expect(rendered).to have_css('.auth__intro-description strong', text: email)
      expect(rendered).to have_css(
        '.auth__intro-description',
        text: strip_tags(t('nds.forgot_password.body_html', email:)),
      )
      expect(rendered).to_not have_content(t('notices.forgot_password.first_paragraph_start'))
    end

    it 'resends the password reset email with the same hidden fields' do
      render

      form = Nokogiri::HTML(rendered).at_css(
        ".auth__actions form[action='#{user_password_path}'][method='post']",
      )
      expect(form).to be_present
      expect(form.at_css('input[type=hidden][name="password_reset_email_form[email]"]')[:value])
        .to eq(email)
      expect(form.at_css('input[type=hidden][name="password_reset_email_form[resend]"]')[:value])
        .to eq('true')
      expect(rendered).to have_css(
        '.auth__actions button.usa-button.usa-button--secondary[type=submit]',
        text: t('nds.forgot_password.resend'),
      )
    end

    it 'does not display the resend notice by default' do
      render

      expect(rendered).to_not have_content(t('notices.forgot_password.resend_email_success'))
    end

    it 'displays a success alert if the email was resent' do
      @resend = true

      render

      expect(rendered).to have_css(
        '.usa-alert--success',
        text: t('notices.forgot_password.resend_email_success'),
      )
    end

    it 'drops the Devise sent notice that repeats the intro' do
      flash[:notice] = t('devise.passwords.send_paranoid_instructions')

      render

      expect(flash[:notice]).to be_nil
      expect(rendered).to_not have_content(t('devise.passwords.send_paranoid_instructions'))
    end

    it 'keeps other notices' do
      flash[:notice] = 'Another notice.'

      render

      expect(flash[:notice]).to eq('Another notice.')
    end
  end
end
