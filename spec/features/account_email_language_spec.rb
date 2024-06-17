require 'rails_helper'

RSpec.describe 'Account email language', allowed_extra_analytics: [:*] do
  let(:user) { user_with_2fa }

  let(:original_email_language) { 'es' }

  before do
    user.email_language = original_email_language
    user.save!
  end

  context 'for a user signed in to their account page' do
    before do
      sign_in_and_2fa_user(user)
    end

    it 'lets them view their current email language' do
      within(page.find('.profile-info-box', text: t('i18n.language'))) do
        expect(page).to have_content(t("account.email_language.name.#{original_email_language}"))
      end
    end

    context 'changing their email language' do
      let('chosen_email_language') { 'fr' }
      before do
        within(page.find('.profile-info-box', text: t('i18n.language'))) do
          click_link(t('forms.buttons.edit'))
        end

        choose t("account.email_language.name.#{chosen_email_language}")
        click_button t('forms.buttons.submit.default')
      end

      it 'reflects the updated language preference' do
        within(page.find('.profile-info-box', text: t('i18n.language'))) do
          expect(page).to have_content(t("account.email_language.name.#{chosen_email_language}"))
        end
      end

      it 'respects the language preference in emails, such as password reset emails' do
        within(page.find('.profile-info-box', text: 'Password')) do
          click_link(t('forms.buttons.edit'))
        end

        fill_in t('forms.passwords.edit.labels.password'),
                with: Features::SessionHelper::VALID_PASSWORD
        fill_in t('components.password_confirmation.confirm_label'),
                with: Features::SessionHelper::VALID_PASSWORD
        click_button 'Update'

        mail = ActionMailer::Base.deliveries.last
        expect(mail.subject).to eq(
          I18n.t(
            'devise.mailer.password_updated.subject',
            locale: chosen_email_language,
          ),
        )
      end
    end
  end
end
