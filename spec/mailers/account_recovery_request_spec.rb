require 'rails_helper'

RSpec.describe UserMailer, type: :mailer do
  describe '#account_recovery_request' do
    let(:user) { create(:user, :fully_registered) }
    let(:email_address) { user.confirmed_email_addresses.first }
    let(:mail) do
      described_class.with(user: user, email_address: email_address).account_recovery_request
    end

    before do
      allow(IdentityConfig.store).to receive(:account_recovery_wait_period_days).and_return(1)
    end

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'

    it 'sends to the confirmed email address' do
      expect(mail.to).to eq([email_address.email])
    end

    %i[en es fr zh].each do |locale|
      context "with #{locale} as the preferred language" do
        before { user.update!(email_language: locale.to_s) }

        it 'includes request confirmation, the waiting period, and security instructions' do
          I18n.with_locale(locale) do
            expect(mail.subject).to eq(
              I18n.t('user_mailer.account_recovery_request.subject', app_name: APP_NAME),
            )
            expect(mail.html_part.body).to have_content(
              I18n.t('user_mailer.account_recovery_request.intro', app_name: APP_NAME),
            )
            expect(mail.html_part.body).to have_css(
              'h1',
              text: I18n.t('user_mailer.account_recovery_request.header', app_name: APP_NAME),
            )
            expect(mail.html_part.body).to have_content(
              I18n.t(
                'user_mailer.account_recovery_request.step_one.title',
                interval: WaitPeriodFormatter.call(1.day),
              ),
            )
            expect(mail.html_part.body).to have_link(
              I18n.t('user_mailer.contact_link_text'), href: MarketingSite.contact_url
            )
            expect(mail.html_part.body).to have_css('table.process-list tr', count: 2)
            expect(mail.html_part.body).to have_css('ul li', count: 4)
            expect(mail.html_part.body).not_to have_link(href: /account_recovery\/verify/)
          end
        end
      end
    end
  end
end
