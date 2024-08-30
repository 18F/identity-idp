require 'rails_helper'

RSpec.describe 'visitor signs up with email language preference' do
  it 'defaults to the current locale' do
    visit sign_up_email_path

    field = page.find_field(
      t('account.email_language.default', language: t("i18n.locale.#{I18n.default_locale}")),
    )
    expect(field).to be_present
    expect(field[:lang]).to eq(I18n.default_locale.to_s)
    (I18n.available_locales - [I18n.default_locale]).each do |locale|
      field = page.find_field(t("i18n.locale.#{locale}"))
      expect(field).to be_present
      expect(field[:lang]).to eq(locale.to_s)
    end

    visit sign_up_email_path(:es)

    field = page.find_field(t('account.email_language.default', language: t('i18n.locale.es')))
    expect(field).to be_present
    expect(field[:lang]).to eq('es')
    (I18n.available_locales - [:es]).each do |locale|
      field = page.find_field(t("i18n.locale.#{locale}"))
      expect(field).to be_present
      expect(field[:lang]).to eq(locale.to_s)
    end
  end

  it 'sends emails in the selected language' do
    email = 'test@example.com'

    visit sign_up_email_path
    choose t('i18n.locale.es')
    check t('sign_up.terms', app_name: APP_NAME)
    fill_in t('forms.registration.labels.email'), with: email
    click_button t('forms.buttons.submit.default')

    emails = unread_emails_for(email)

    expect(emails.last.subject).to eq(
      t('user_mailer.email_confirmation_instructions.subject', locale: :es),
    )
  end
end
