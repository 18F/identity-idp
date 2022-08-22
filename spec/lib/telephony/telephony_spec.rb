require 'rails_helper'

RSpec.describe Telephony do
  include_context 'telephony'

  describe '.phone_info' do
    let(:phone_number) { '+18888675309' }
    subject(:phone_info) { Telephony.phone_info(phone_number) }

    context 'with test adapter' do
      before { Telephony.config { |c| c.adapter = :test } }

      it 'uses the test adapter' do
        expect(phone_info.type).to eq(:mobile)
      end
    end

    context 'with pinpoint adapter' do
      before do
        Telephony.config { |c| c.adapter = :pinpoint }
        Aws.config[:pinpoint] = {
          stub_responses: {
            phone_number_validate: {
              number_validate_response: { phone_type: 'VOIP' },
            },
          },
        }
      end

      it 'uses the pinpoint adapter' do
        expect(phone_info.type).to eq(:voip)
      end
    end
  end

  # Assertions validated against https://twiliodeved.github.io/message-segment-calculator/
  describe '.sms_character_length' do
    it 'calculates correct length of simple GSM messages' do
      expect(Telephony.sms_character_length('')).to eq 0
      expect(Telephony.sms_character_length('login')).to eq 5
      expect(Telephony.sms_character_length('b' * 170)).to eq 170
    end

    it 'calculates correct length of more complicated GSM messages' do
      # Each of these characters is in GSM 03.38 and counts as 1 character
      # and there are 124 of them
      expect(
        Telephony.sms_character_length(
          'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyzàÅåÄäÇÉéèìÑñòØøÖöùÜ'\
          'üÆæß0123456789&*@:,¤$=!>#-¡¿(<%.+£?")§;\'/_¥ΔΦΓΛΩΠΨΣΘΞ',
        ),
      ).to eq 124

      # The double-length characters should count as twice their length
      expect(Telephony.sms_character_length(Telephony::GSM_DOUBLE_CHARACTERS.join(''))).
        to eq(Telephony::GSM_DOUBLE_CHARACTERS.length * 2)

      # Space, new line, and carriage return all count as 1 character
      expect(Telephony.sms_character_length("\n\r ")).to eq 3

      expect(Telephony.sms_character_length("Login.gov\nParty")).to eq 15

      random_double_character = Telephony::GSM_DOUBLE_CHARACTERS.to_a.sample
      expect(Telephony.sms_character_length("abc\n¥ΔΦΓΛΩΠΨΣΘΞ#{random_double_character}")).
        to eq 17
    end

    it 'calculates correct length of messages containing non-GSM characters' do
      expect(Telephony.sms_character_length('âabcó')).to eq 5

      # Messages containing non-GSM characters count double-length GSM as 1 character
      # because of the different encoding
      expect(Telephony.sms_character_length('|ó')).to eq 2
    end

    it 'calculates correct length of messages containing emoji' do
      expect(Telephony.sms_character_length('😴')).to eq 2
      expect(Telephony.sms_character_length('🛌')).to eq 2

      # [0x1f6b6, 0x1f3fd, 0x200d, 0x2640, 0xfe0f]
      # 0x1f6b6 and 0x1f3fd count as two since they are greater than 0xffff
      expect(Telephony.sms_character_length('🚶🏽‍♀️')).to eq 7

      # [0x1f93e, 0x1f3fd, 0x200d, 0x2640, 0xfe0f]
      # 0x1f93e and 0x1f3fd count as two since they are greater than 0xffff
      expect(Telephony.sms_character_length('🤾🏽‍♀️')).to eq 7

      # [0x1f469, 0x200d, 0x2764, 0xfe0f, 0x200d, 0x1f469]
      # 0x1f469 and 0x1f469 count as two since they are greater than 0xffff
      expect(Telephony.sms_character_length('👩‍❤️‍👩')).to eq 8

      # [0x1f1fa, 0x1f1f8]
      # 0x1f1fa and 0x1f1f8 count as two since they are greater than 0xffff
      expect(Telephony.sms_character_length('🇺🇸')).to eq 4
    end
  end

  describe '.sms_parts' do
    it 'correctly calculates number of parts in simple GSM messages' do
      # Maximum characters in a single message that doesn't need to be split is 160
      expect(Telephony.sms_parts('a')).to eq 1
      expect(Telephony.sms_parts('a' * 160)).to eq 1

      # Maximum characters in a multi-part message is 153
      expect(Telephony.sms_parts('a' * 306)).to eq 2
      expect(Telephony.sms_parts('a' * 307)).to eq 3
    end

    it 'correctly calculates number of parts in more complicated GSM messages' do
      # Double-length characters can fit half as many characters in a given message or part
      expect(Telephony.sms_parts('|')).to eq 1
      expect(Telephony.sms_parts('|' * 80)).to eq 1
      expect(Telephony.sms_parts('|' * 81)).to eq 2
      expect(Telephony.sms_parts('|' * 153)).to eq 2
      expect(Telephony.sms_parts('|' * 154)).to eq 3

      expect(Telephony.sms_parts('a' * 159 + '|')).to eq 2
    end

    it 'correctly calculates number of parts in non-GSM messages' do
      # Maximum characters in a single non-GSM message that doesn't need to be split is 70
      expect(Telephony.sms_parts('🤠' * 35)).to eq 1
      expect(Telephony.sms_parts('a' * 68 + '😑')).to eq 1
      expect(Telephony.sms_parts('a' * 69 + '😑')).to eq 2
      expect(Telephony.sms_parts('|' * 68 + '😑')).to eq 1
      expect(Telephony.sms_parts('|' * 69 + '😑')).to eq 2
      expect(Telephony.sms_parts('🇺🇸' * 17)).to eq 1
      expect(Telephony.sms_parts('🇺🇸' * 18)).to eq 2
    end
  end
end
