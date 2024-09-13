require 'rails_helper'

RSpec.describe UserAlerts::AlertUserAboutAccountVerified do
  describe '#call' do
    let(:user) { profile.user }
    let(:profile) do
      create(
        :profile,
        :active,
        initiating_service_provider: service_provider,
      )
    end
    let(:service_provider) { create(:service_provider) }

    it 'sends an email to all confirmed email addresses' do
      create_list(:email_address, 2, user: user)
      create(:email_address, user: user, confirmed_at: nil)
      confirmed_email_addresses = user.confirmed_email_addresses

      described_class.call(profile: profile)

      expect_delivered_email_count(3)
      expect_delivered_email(
        to: [confirmed_email_addresses[0].email],
        subject: t('user_mailer.account_verified.subject', sp_name: service_provider.friendly_name),
      )
      expect_delivered_email(
        to: [confirmed_email_addresses[1].email],
        subject: t('user_mailer.account_verified.subject', sp_name: service_provider.friendly_name),
      )
      expect_delivered_email(
        to: [confirmed_email_addresses[2].email],
        subject: t('user_mailer.account_verified.subject', sp_name: service_provider.friendly_name),
      )
    end

    context 'when no service provider initiated the proofing event' do
      let(:service_provider) { nil }

      it 'sends the email with Login.gov as the initiating service provider' do
        described_class.call(profile: profile)

        expect_delivered_email(
          to: [user.confirmed_email_addresses.first.email],
          subject: t('user_mailer.account_verified.subject', sp_name: APP_NAME),
        )
      end
    end
  end
end
