require 'rails_helper'

RSpec.describe UserMailer, type: :mailer do
  let(:user) { create(:user, :fully_registered) }
  let(:email_address) { user.confirmed_email_addresses.first }
  let(:token) { SecureRandom.uuid }

  describe '#account_recovery_granted' do
    let(:mail) do
      described_class.with(user: user, email_address: email_address)
        .account_recovery_granted(token: token)
    end

    before do
      allow(IdentityConfig.store).to receive(:account_recovery_token_valid_for_hours)
        .and_return(24)
    end

    # Delivered synchronously only. Enqueuing would serialize the raw tokens
    # into the good_jobs table in plaintext.
    it_behaves_like 'a system email', synchronous_only: true
    it_behaves_like 'an email that respects user email locale preference'

    it 'sends to the confirmed email address' do
      expect(mail.to).to eq([email_address.email])
    end

    it 'includes the recovery link carrying the raw token' do
      expect(mail.html_part.body).to have_link(
        href: %r{/account_recovery/verify\?.*token=#{token}},
      )
    end

    it 'directs cancellation to sign in' do
      expect(mail.html_part.body).to have_link(
        I18n.t('user_mailer.account_recovery_granted.cancel_link_text', app_name: APP_NAME),
        href: new_user_session_url,
      )
    end

    %i[en es fr zh].each do |locale|
      context "with #{locale} as the preferred language" do
        before { user.update!(email_language: locale.to_s) }

        it 'includes the subject, intro, expiration, and cancel instructions' do
          I18n.with_locale(locale) do
            expect(mail.subject).to eq(
              I18n.t('user_mailer.account_recovery_granted.subject', app_name: APP_NAME),
            )
            expect(mail.html_part.body).to have_content(
              I18n.t('user_mailer.account_recovery_granted.intro', app_name: APP_NAME),
            )
            expect(mail.html_part.body).to have_css(
              'h1',
              text: I18n.t('user_mailer.account_recovery_granted.header', app_name: APP_NAME),
            )
            expect(mail.html_part.body).to have_content(
              I18n.t(
                'user_mailer.account_recovery_granted.expires',
                interval: WaitPeriodFormatter.call(24.hours),
              ),
            )
            expect(mail.html_part.body).to have_content(
              I18n.t('user_mailer.account_recovery_granted.password_reminder'),
            )
            expect(mail.html_part.body).to have_content(
              I18n.t(
                'user_mailer.account_recovery_granted.unrequested_html',
                cancel_link_html: I18n.t(
                  'user_mailer.account_recovery_granted.cancel_link_text',
                  app_name: APP_NAME,
                ),
              ),
            )
            expect(mail.html_part.body).to have_link(
              I18n.t(
                'user_mailer.account_recovery_granted.cancel_link_text',
                app_name: APP_NAME,
              ),
            )
          end
        end
      end
    end

    # The granted email is deliberately simpler than the request email, which
    # carries the two-step waiting period explanation.
    it 'does not repeat the waiting period process list' do
      expect(mail.html_part.body).to_not have_css('table.process-list')
    end
  end

  describe '#account_recovery_cancelled' do
    let(:mail) do
      described_class.with(user: user, email_address: email_address)
        .account_recovery_cancelled
    end

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'

    it 'sends to the confirmed email address' do
      expect(mail.to).to eq([email_address.email])
    end

    it 'never contains a recovery link' do
      expect(mail.html_part.body).to_not have_link(href: %r{/account_recovery/verify})
    end

    %i[en es fr zh].each do |locale|
      context "with #{locale} as the preferred language" do
        before { user.update!(email_language: locale.to_s) }

        it 'confirms the cancellation and that methods are unchanged' do
          I18n.with_locale(locale) do
            expect(mail.subject).to eq(
              I18n.t('user_mailer.account_recovery_cancelled.subject', app_name: APP_NAME),
            )
            expect(mail.html_part.body).to have_content(
              I18n.t('user_mailer.account_recovery_cancelled.intro', app_name: APP_NAME),
            )
            expect(mail.html_part.body).to have_content(
              I18n.t('user_mailer.account_recovery_cancelled.methods_unchanged'),
            )
            expect(mail.html_part.body).to have_link(
              I18n.t('user_mailer.contact_link_text'), href: MarketingSite.contact_url
            )
          end
        end
      end
    end
  end
end
