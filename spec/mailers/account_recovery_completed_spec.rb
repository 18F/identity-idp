require 'rails_helper'

RSpec.describe UserMailer, type: :mailer do
  describe '#account_recovery_completed' do
    let(:user) { create(:user, :fully_registered) }
    let(:email_address) { user.confirmed_email_addresses.first }
    let(:removed_mfa_methods) { %w[auth_app phone] }
    let(:mail) do
      described_class.with(user: user, email_address: email_address)
        .account_recovery_completed(removed_mfa_methods: removed_mfa_methods)
    end

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'

    it 'confirms recovery and lists the removed authentication methods' do
      expect(mail.to).to eq([email_address.email])
      expect(mail.subject).to eq(
        t('user_mailer.account_recovery_completed.subject', app_name: APP_NAME),
      )
      expect(mail.html_part.body).to have_content(
        t('user_mailer.account_recovery_completed.intro', app_name: APP_NAME),
      )
      expect(mail.html_part.body).to have_css(
        'h1',
        text: t('user_mailer.account_recovery_completed.header', app_name: APP_NAME),
      )
      expect(mail.html_part.body).to have_content(
        t('user_mailer.account_recovery_completed.removed'),
      )
      expect(mail.html_part.body).to have_content(t('account_recovery.mfa_methods.auth_app'))
      expect(mail.html_part.body).to have_content(t('account_recovery.mfa_methods.phone'))
      expect(mail.html_part.body).to have_link(
        t('user_mailer.contact_link_text'), href: MarketingSite.contact_url
      )
    end

    it 'does not leak a recovery link' do
      expect(mail.html_part.body).to_not have_link(href: %r{account_recovery/verify})
    end

    context 'with no removed methods' do
      let(:removed_mfa_methods) { [] }

      it 'omits the removed methods section' do
        expect(mail.html_part.body).to_not have_content(
          t('user_mailer.account_recovery_completed.removed'),
        )
        expect(mail.html_part.body).to have_content(
          t('user_mailer.account_recovery_completed.intro', app_name: APP_NAME),
        )
      end
    end

    context 'with an unrecognized method name' do
      let(:removed_mfa_methods) { %w[auth_app not_a_real_method] }

      it 'lists only the names it can translate' do
        expect(mail.html_part.body).to have_content(t('account_recovery.mfa_methods.auth_app'))
        # One removed method, plus the four standard security instructions.
        expect(mail.html_part.body).to have_css('ul li', count: 5)
      end
    end

    %i[en es fr zh].each do |locale|
      context "with #{locale} as the preferred language" do
        before { user.update!(email_language: locale.to_s) }

        it 'is localized' do
          I18n.with_locale(locale) do
            expect(mail.subject).to eq(
              I18n.t('user_mailer.account_recovery_completed.subject', app_name: APP_NAME),
            )
            expect(mail.html_part.body).to have_content(
              I18n.t('user_mailer.account_recovery_completed.intro', app_name: APP_NAME),
            )
          end
        end
      end
    end
  end
end
