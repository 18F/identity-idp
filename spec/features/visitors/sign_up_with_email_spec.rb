require 'rails_helper'

feature 'Visitor signs up with email address' do
  scenario 'visitor can sign up with valid email address' do
    email = 'test@example.com'
    sign_up_with(email)

    expect(page).to have_content t('notices.signed_up_but_unconfirmed.first_paragraph_start')
    expect(page).to have_content t('notices.signed_up_but_unconfirmed.first_paragraph_end')
    expect(page).to have_content email
    expect(Funnel::Registration::TotalSubmittedCount.call).to eq(1)
    expect(Funnel::Registration::TotalRegisteredCount.call).to eq(0)
  end

  scenario 'visitor cannot sign up with invalid email address', js: true do
    sign_up_with('bogus')

    expect(page).to have_content t('valid_email.validations.email.invalid')
  end

  scenario 'visitor cannot sign up with email with invalid domain name' do
    invalid_addresses = [
      'foo@bar.com',
      'foo@example.com',
    ]
    allow(ValidateEmail).to receive(:mx_valid?).and_return(false)

    invalid_addresses.each do |email|
      sign_up_with(email)
      expect(page).to have_content(t('valid_email.validations.email.invalid'))
    end
  end

  scenario 'visitor cannot sign up with empty email address', js: true do
    sign_up_with('')

    expect(page).to have_content t('simple_form.required.text')
  end

  context 'user signs up and sets password, tries to sign up again' do
    scenario 'sends email saying someone tried to sign up with their email address' do
      user = create(:user)

      expect { sign_up_with(user.email) }.
        to change { ActionMailer::Base.deliveries.count }.by(1)

      expect(last_email.html_part.body).to have_content(
        t('user_mailer.signup_with_your_email.intro_html', app_name: APP_NAME),
      )
    end
  end

  scenario 'taken to profile page after sign up flow complete' do
    visit sign_up_email_path
    sign_up_and_2fa_ial1_user

    expect(Funnel::Registration::TotalSubmittedCount.call).to eq(1)
    expect(Funnel::Registration::TotalRegisteredCount.call).to eq(1)
    expect(current_path).to eq account_path
  end

  it 'returns a bad request if the email contains invalid bytes' do
    suppress_output do
      sign_up_with("test@\xFFbar\xF8.com")
      expect(page).to have_content 'Bad request'
    end
  end

  it 'throttles sending confirmations after limit is reached' do
    email = 'test@test.com'
    sign_up_with(email)

    starting_count = unread_emails_for(email).size
    max_attempts = IdentityConfig.store.reg_unconfirmed_email_max_attempts
    max_attempts.times do |i|
      sign_up_with(email)
      expect(unread_emails_for(email).size).to eq(starting_count + i + 1)
    end

    expect(unread_emails_for(email).size).to eq(starting_count + max_attempts)
    sign_up_with(email)
    expect(unread_emails_for(email).size).to eq(starting_count + max_attempts)
  end
end
