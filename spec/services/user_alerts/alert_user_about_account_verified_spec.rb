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

      confirmed_email_addresses.each do |email_address|
        expect_delivered_email(
          to: [email_address.email],
          subject: t('user_mailer.account_verified.subject', app_name: APP_NAME),
        )
      end
    end

    context 'when no service provider initiated the proofing event' do
      let(:service_provider) { nil }

      it 'sends the email linking to Login.gov' do
        described_class.call(profile: profile)

        expect_delivered_email(
          to: [user.last_sign_in_email_address.email],
          subject: t('user_mailer.account_verified.subject', app_name: APP_NAME),
          body: [
            'http://www.example.com/redirect/return_to_sp/account_verified_cta',
          ],
        )
      end
    end

    context 'when a service provider with no url' do
      let(:service_provider) { ServiceProvider.new }

      it 'sends an email without the call to action' do
        described_class.call(profile: profile)

        email_body = last_email.text_part.decoded.squish
        expect(email_body).to_not include(
          'http://www.example.com/redirect/return_to_sp/account_verified_cta',
        )
      end
    end

    context 'when a service provider does have a url' do
      let(:service_provider) do
        create(
          :service_provider,
          friendly_name: 'Example App',
          return_to_sp_url: 'http://example.com',
        )
      end

      it 'sends an email with the call to action linking to the sp' do
        described_class.call(profile: profile)

        expect_delivered_email(
          to: [user.last_sign_in_email_address.email],
          subject: t('user_mailer.account_verified.subject', app_name: APP_NAME),
          body: ['http://example.com'],
        )
      end
    end

    context 'sending a proofing completed SMS message' do
      let(:phone) { '+1 202-555-1234' }

      before do
        allow(Telephony).to receive(:send_proofing_completion_confirmation)
      end

      context 'when the profile is enhanced' do
        let(:profile) do
          create(
            :profile,
            :active,
            idv_level: :unsupervised_with_selfie,
            initiating_service_provider: service_provider,
          )
        end

        it 'sends an SMS proofing completion confirmation to the given phone' do
          described_class.call(profile: profile, phone: phone)

          expect(Telephony).to have_received(:send_proofing_completion_confirmation).with(
            to: phone,
            country_code: Phonelib.parse(phone).country,
            sp_or_app_name: service_provider.friendly_name,
          )
        end

        context 'when no service provider initiated the proofing event' do
          let(:service_provider) { nil }

          it 'falls back to the app name' do
            described_class.call(profile: profile, phone: phone)

            expect(Telephony).to have_received(:send_proofing_completion_confirmation).with(
              to: phone,
              country_code: Phonelib.parse(phone).country,
              sp_or_app_name: APP_NAME,
            )
          end
        end

        context 'when no phone is given' do
          it 'does not send an SMS message' do
            described_class.call(profile: profile)

            expect(Telephony).to_not have_received(:send_proofing_completion_confirmation)
          end
        end
      end

      context 'when the profile is not enhanced' do
        it 'does not send an SMS message' do
          described_class.call(profile: profile, phone: phone)

          expect(Telephony).to_not have_received(:send_proofing_completion_confirmation)
        end
      end
    end

    context 'when the profile is enhanced and the user has a locale preference' do
      let(:phone) { '+1 202-555-1234' }
      let(:profile) do
        create(
          :profile,
          :active,
          idv_level: :unsupervised_with_selfie,
          initiating_service_provider: service_provider,
        )
      end

      it 'sends the sms respecting the English locale preference' do
        user.update!(email_language: 'en')

        freeze_time do
          described_class.call(profile: profile, phone: phone)

          last_message = Telephony::Test::Message.messages.last
          expect(last_message.to).to eq(phone)
          expect(last_message.body).to eq(expected_sms_body('en'))
        end
      end

      it 'sends the sms respecting the French locale preference' do
        user.update!(email_language: 'fr')

        freeze_time do
          described_class.call(profile: profile, phone: phone)

          last_message = Telephony::Test::Message.messages.last
          expect(last_message.to).to eq(phone)
          expect(last_message.body).to eq(expected_sms_body('fr'))
        end
      end

      it 'sends the sms respecting the Spanish locale preference' do
        user.update!(email_language: 'es')

        freeze_time do
          described_class.call(profile: profile, phone: phone)

          last_message = Telephony::Test::Message.messages.last
          expect(last_message.to).to eq(phone)
          expect(last_message.body).to eq(expected_sms_body('es'))
        end
      end

      def expected_sms_body(locale)
        I18n.with_locale(locale) do
          I18n.t(
            'telephony.proofing_completion_confirmation.sms',
            app_name: APP_NAME,
            proof_date: I18n.l(Time.zone.now, format: :sms_date, locale: locale),
            sp_or_app_name: service_provider.friendly_name,
            contact_url: MarketingSite.contact_url,
            locale: locale,
          )
        end
      end
    end
  end
end
