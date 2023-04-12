require 'aws-sdk-pinpoint'
require 'aws-sdk-pinpointsmsvoice'
require 'forwardable'
require 'i18n'
require 'telephony/util'
require 'telephony/alert_sender'
require 'telephony/configuration'
require 'telephony/errors'
require 'telephony/otp_sender'
require 'telephony/phone_number_info'
require 'telephony/response'
require 'telephony/test/call'
require 'telephony/test/message'
require 'telephony/test/error_simulator'
require 'telephony/test/sms_sender'
require 'telephony/test/voice_sender'
require 'telephony/pinpoint/aws_credential_builder'
require 'telephony/pinpoint/pinpoint_helper'
require 'telephony/pinpoint/opt_out_manager'
require 'telephony/pinpoint/sms_sender'
require 'telephony/pinpoint/voice_sender'

module Telephony
  # GSM 03.38 character set
  # https://docs.aws.amazon.com/pinpoint/latest/userguide/channels-sms-limitations-characters.html
  GSM_NON_WHITE_SPACE_CHARACTERS = %w[
    A B C D E F G H I J K L M N O P Q R S T U V W X Y Z a b c d e
    f g h i j k l m n o p q r s t u v w x y z à Å å Ä ä Ç É é è ì Ñ ñ ò Ø ø Ö ö ù Ü ü Æ æ ß 0 1 2 3
    4 5 6 7 8 9 & * @ : , ¤ $ = ! > # - ¡ ¿ ( < % . + £ ? " ) § ; ' / _ ¥ Δ Φ Γ Λ Ω Π Ψ Σ Θ Ξ
  ].to_set.freeze
  GSM_WHITESPACE_CHARACTERS = ["\n", "\r", ' '].to_set.freeze
  GSM_DOUBLE_CHARACTERS = ['^', '{', '}', '\\', '[', ']', '~', '|', '€'].to_set.freeze
  GSM_CHARACTERS = (GSM_NON_WHITE_SPACE_CHARACTERS + GSM_WHITESPACE_CHARACTERS +
                   GSM_DOUBLE_CHARACTERS).freeze

  UCS_2_BASIC_CHAR_MAX = 0xFFFF

  extend SingleForwardable

  def self.config
    @config ||= Configuration.new
    yield @config if block_given?
    @config
  end

  def self.send_authentication_otp(to:, otp:, expiration:, otp_format:,
                                   channel:, domain:, country_code:, extra_metadata:)
    OtpSender.new(
      to: to,
      otp: otp,
      expiration: expiration,
      otp_format: otp_format,
      channel: channel,
      domain: domain,
      country_code: country_code,
      extra_metadata: extra_metadata,
    ).send_authentication_otp
  end

  def self.send_confirmation_otp(to:, otp:, expiration:, otp_format:,
                                 channel:, domain:, country_code:, extra_metadata:)
    OtpSender.new(
      to: to,
      otp: otp,
      expiration: expiration,
      otp_format: otp_format,
      channel: channel,
      domain: domain,
      country_code: country_code,
      extra_metadata: extra_metadata,
    ).send_confirmation_otp
  end

  def self.alert_sender
    AlertSender.new
  end

  def_delegators :alert_sender,
                 :send_doc_auth_link,
                 :send_personal_key_regeneration_notice,
                 :send_personal_key_sign_in_notice,
                 :send_account_reset_notice,
                 :send_account_reset_cancellation_notice

  # @param [String] phone_number phone number in E.164 format
  # @return [PhoneNumberInfo] info about the phone number
  def self.phone_info(phone_number)
    sender = case Telephony.config.adapter
    when :pinpoint
      Pinpoint::SmsSender.new
    when :test
      Test::SmsSender.new
    end

    sender.phone_info(phone_number)
  end

  # A character in a GSM 03.38 message counts as one character, unless it is explicitly one of
  # the characters that requires an escape sequence, which makes it count as two characters.
  #
  # Messages that contain non-GSM 03.38 characters are encoded as UCS-2 with 2-byte characters.
  # Codepoints less than 0xFFFF can be represented as one character, but other codepoints are
  # encoded as two.
  #
  # This method does not handle message length added for multi-part message headers.
  def self.sms_character_length(text)
    if gsm_chars_only?(text)
      text.chars.sum do |character|
        if GSM_DOUBLE_CHARACTERS.include?(character)
          2
        else
          1
        end
      end
    else
      text.chars.sum do |char|
        char.codepoints.sum do |codepoint|
          if codepoint <= UCS_2_BASIC_CHAR_MAX
            1
          else
            2
          end
        end
      end
    end
  end

  # A single GSM 03.38 message can contain up to 160 characters. If the length is beyond that,
  # the message is split into parts containing 153 characters each. The capacity is lower because
  # messages must now also encode information about message order.
  #
  # UCS-2 messages behave similarly, but the size is limited to 70 and 67 characters respectively.
  def self.sms_parts(text)
    length = sms_character_length(text)

    if gsm_chars_only?(text)
      gsm_parts(length)
    else
      non_gsm_parts(length)
    end
  end

  def self.gsm_chars_only?(text)
    text.chars.all? { |x| GSM_CHARACTERS.include?(x) }
  end

  def self.gsm_parts(length)
    if length <= 160
      1
    else
      (length / 153.0).ceil
    end
  end

  def self.non_gsm_parts(length)
    if length <= 70
      1
    else
      (length / 67.0).ceil
    end
  end

  private_class_method :gsm_parts, :non_gsm_parts
end
