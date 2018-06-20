require 'rails_helper'

feature 'Email confirmation during sign up' do
  scenario 'confirms valid email and sets valid password' do
    allow(Figaro.env).to receive(:participate_in_dap).and_return('true')
    reset_email
    email = 'test@example.com'
    sign_up_with(email)
    open_email(email)
    visit_in_email(t('mailer.confirmation_instructions.link_text'))

    expect(page.html).not_to include(t('notices.dap_participation'))
    expect(page).to have_content t('devise.confirmations.confirmed_but_must_set_password')
    expect(page).to have_title t('titles.confirmations.show')
    expect(page).to have_content t('forms.confirmation.show_hdr')

    fill_in 'password_form_password', with: Features::SessionHelper::VALID_PASSWORD
    click_button t('forms.buttons.continue')

    expect(current_url).to eq two_factor_options_url
    expect(page).to_not have_content t('devise.confirmations.confirmed_but_must_set_password')
  end

  context 'user signs up twice without confirming email' do
    it 'sends the user the confirmation email again' do
      email = 'test@example.com'

      expect { sign_up_with(email) }.
        to change { ActionMailer::Base.deliveries.count }.by(1)
      expect(last_email.html_part.body).to have_content(
        t('devise.mailer.confirmation_instructions.subject')
      )

      expect { sign_up_with(email) }.
        to change { ActionMailer::Base.deliveries.count }.by(1)
      expect(last_email.html_part.body).to have_content(
        t('devise.mailer.confirmation_instructions.subject')
      )
    end
  end

  context 'user signs up and requests confirmation email again' do
    it 'sends the confirmation email again' do
      sign_up_with('test@example.com')

      expect { click_on t('links.resend') }.
        to change { ActionMailer::Base.deliveries.count }.by(1)

      expect(last_email.html_part.body).to have_content(
        t('devise.mailer.confirmation_instructions.subject')
      )
      expect(page).to have_content(
        t('notices.resend_confirmation_email.success')
      )
    end
  end

  context 'confirmed user is signed in and tries to confirm again' do
    it 'redirects the user to the profile' do
      sign_up_and_2fa_loa1_user

      visit sign_up_create_email_confirmation_url(confirmation_token: @raw_confirmation_token)

      expect(current_url).to eq account_url
    end
  end

  context 'confirmed user is signed out and tries to confirm again' do
    it 'redirects to sign in page with message that user is already confirmed' do
      allow(Figaro.env).to receive(:participate_in_dap).and_return('true')
      sign_up_and_set_password

      visit destroy_user_session_url
      visit sign_up_create_email_confirmation_url(confirmation_token: @raw_confirmation_token)

      expect(page.html).to include(t('notices.dap_participation'))
      action = t('devise.confirmations.sign_in')
      expect(page).
        to have_content t('devise.confirmations.already_confirmed', action: action)
      expect(current_url).to eq new_user_session_url
    end
  end
end
