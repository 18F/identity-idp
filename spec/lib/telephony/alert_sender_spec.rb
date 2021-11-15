describe Telephony::AlertSender do
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
        I18n.t('telephony.account_reset_notice'),
      )
    end
  end

  describe 'send_account_reset_cancellation_notice' do
    it 'sends the correct message' do
      subject.send_account_reset_cancellation_notice(to: recipient, country_code: 'US')

      last_message = Telephony::Test::Message.messages.last
      expect(last_message.to).to eq(recipient)
      expect(last_message.body).to eq(I18n.t('telephony.account_reset_cancellation_notice'))
    end
  end

  describe 'send_doc_auth_link' do
    let(:link) do
      'https://idp.int.identitysandbox.com/verify/capture-doc/mobile-front-image?token=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
    end

    it 'sends the correct message' do
      subject.send_doc_auth_link(to: recipient, link: link, country_code: 'US')

      last_message = Telephony::Test::Message.messages.last
      expect(last_message.to).to eq(recipient)
      expect(last_message.body).to eq(I18n.t('telephony.doc_auth_link', link: link))
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
          subject.send_doc_auth_link(to: recipient, link: link, country_code: 'US')

          last_message = Telephony::Test::Message.messages.last
          first160 = last_message.body[0...160]
          expect(first160).to include(link)
        end
      end
    end

    it 'warns if the link is longer than 160 characters' do
      long_link = 'a' * 161

      expect(Telephony.config.logger).to receive(:warn)

      subject.send_doc_auth_link(to: recipient, link: long_link, country_code: 'US')
    end
  end

  describe 'send_personal_key_regeneration_notice' do
    it 'sends the correct message' do
      subject.send_personal_key_regeneration_notice(to: recipient, country_code: 'US')

      last_message = Telephony::Test::Message.messages.last
      expect(last_message.to).to eq(recipient)
      expect(last_message.body).to eq(I18n.t('telephony.personal_key_regeneration_notice'))
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

  describe 'send_join_keyword_response' do
    it 'sends the correct message' do
      subject.send_join_keyword_response(to: recipient, country_code: 'US')

      last_message = Telephony::Test::Message.messages.last
      expect(last_message.to).to eq(recipient)
      expect(last_message.body).to eq(I18n.t('telephony.join_keyword_response'))
    end
  end

  describe 'send_stop_keyword_response' do
    it 'sends the correct message' do
      subject.send_stop_keyword_response(to: recipient, country_code: 'US')

      last_message = Telephony::Test::Message.messages.last
      expect(last_message.to).to eq(recipient)
      expect(last_message.body).to eq(I18n.t('telephony.stop_keyword_response'))
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

        it 'fits in an SMS messages (160 chars)' do
          subject.send_stop_keyword_response(to: recipient, country_code: 'US')

          last_message = Telephony::Test::Message.messages.last
          expect(last_message.body.size).to be <= 160
        end
      end
    end
  end

  describe 'send_help_keyword_response' do
    it 'sends the correct message' do
      subject.send_help_keyword_response(to: recipient, country_code: 'US')

      last_message = Telephony::Test::Message.messages.last
      expect(last_message.to).to eq(recipient)
      expect(last_message.body).to eq(I18n.t('telephony.help_keyword_response'))
    end
  end

  context 'with the pinpoint adapter enabled' do
    let(:configured_adapter) { :pinpoint }

    it 'uses the poinpoint adapter to send messages' do
      adapter = instance_double(Telephony::Pinpoint::SmsSender)
      expect(adapter).to receive(:send).with(
        message: I18n.t('telephony.join_keyword_response'),
        to: recipient,
        country_code: 'US',
      )
      expect(Telephony::Pinpoint::SmsSender).to receive(:new).and_return(adapter)

      subject.send_join_keyword_response(to: recipient, country_code: 'US')
    end
  end
end
