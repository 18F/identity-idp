require 'rails_helper'

RSpec.describe Telephony::AlertSender do
  let(:configured_adapter) { :test }
  let(:recipient) { '+1 (202) 555-5000' }

  before do
    allow(Telephony.config).to receive(:adapter).and_return(configured_adapter)
    Telephony::Test::Message.clear_messages
  end

  describe 'send_account_reset_notice' do
    it 'sends the correct message' do
      subject.send_account_reset_notice(to: recipient, country_code: 'US')

      last_message = Telephony::Test::Message.messages.last
      expect(last_message.to).to eq(recipient)
      expect(last_message.body).to eq(
        I18n.t('telephony.account_reset_notice', app_name: APP_NAME),
      )
    end
  end

  describe 'send_account_reset_cancellation_notice' do
    it 'sends the correct message' do
      subject.send_account_reset_cancellation_notice(to: recipient, country_code: 'US')

      last_message = Telephony::Test::Message.messages.last
      expect(last_message.to).to eq(recipient)
      expect(last_message.body).to eq(
        I18n.t('telephony.account_reset_cancellation_notice', app_name: APP_NAME),
      )
    end
  end

  describe 'send_doc_auth_link' do
    let(:link) do
      'https://idp.int.identitysandbox.com/verify/capture-doc/mobile-front-image?token=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
    end
    let(:app_name) { APP_NAME }
    let(:sp_or_app_name) { 'Batman.gov' }

    it 'sends the correct message' do
      subject.send_doc_auth_link(
        to: recipient,
        link: link,
        country_code: 'US',
        sp_or_app_name: sp_or_app_name,
      )

      last_message = Telephony::Test::Message.messages.last
      expect(last_message.to).to eq(recipient)
      expect(last_message.body).to eq(
        I18n.t(
          'telephony.doc_auth_link',
          app_name: app_name,
          link: link,
          sp_or_app_name: sp_or_app_name,
        ),
      )
    end

    I18n.available_locales.each do |locale|
      context "in locale #{locale}" do
        around do |ex|
          orig_locale = I18n.locale
          I18n.locale = locale
          ex.run
        ensure
          I18n.locale = orig_locale
        end

        it 'puts the URL in the first 160 characters, so it stays within a single SMS message' do
          subject.send_doc_auth_link(
            to: recipient,
            link: link,
            country_code: 'US',
            sp_or_app_name: sp_or_app_name,
          )

          last_message = Telephony::Test::Message.messages.last
          first160 = last_message.body[0...160]
          expect(first160).to include(link)
        end
      end
    end

    it 'warns if the link is longer than 160 characters' do
      long_link = 'a' * 161

      expect(Telephony.config.logger).to receive(:warn)

      subject.send_doc_auth_link(
        to: recipient,
        link: long_link,
        country_code: 'US',
        sp_or_app_name: sp_or_app_name,
      )
    end
  end

  describe 'send_personal_key_regeneration_notice' do
    it 'sends the correct message' do
      subject.send_personal_key_regeneration_notice(to: recipient, country_code: 'US')

      last_message = Telephony::Test::Message.messages.last
      expect(last_message.to).to eq(recipient)
      expect(last_message.body).to eq(
        I18n.t('telephony.personal_key_regeneration_notice', app_name: APP_NAME),
      )
    end
  end

  describe 'send_personal_key_sign_in_notice' do
    it 'sends the correct message' do
      subject.send_personal_key_sign_in_notice(to: recipient, country_code: 'US')

      last_message = Telephony::Test::Message.messages.last
      expect(last_message.to).to eq(recipient)
      expect(last_message.body).to eq(I18n.t('telephony.personal_key_sign_in_notice'))
    end
  end
end
