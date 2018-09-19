require 'typhoeus/adapters/faraday'

module TwilioService
  class Utils
    cattr_accessor :telephony_service do
      Twilio::REST::Client
    end

    def initialize
      @http_client = Twilio::HTTP::Client.new(timeout: Figaro.env.twilio_timeout.to_i)
      @client = if FeatureManagement.telephony_disabled?
                  NullTwilioClient.new
                else
                  twilio_client
                end
      @client.http_client.adapter = :typhoeus
    end

    def place_call(params = {})
      sanitize_errors do
        params = params.reverse_merge(from: from_number)
        client.calls.create(params)
      end
    end

    def send_sms(params = {})
      sanitize_errors do
        params = params.reverse_merge(
          messaging_service_sid: Figaro.env.twilio_messaging_service_sid
        )
        client.messages.create(params)
      end
    end

    def phone_number
      @phone_number ||= random_phone_number
    end

    def from_number
      "+1#{phone_number}"
    end

    private

    attr_reader :client, :http_client

    def twilio_client
      telephony_service.new(TWILIO_SID, TWILIO_AUTH_TOKEN, nil, nil, @http_client)
    end

    def random_phone_number
      TWILIO_NUMBERS.sample
    end

    def sanitize_errors
      tries ||= 2
      yield
    rescue Twilio::REST::RestError => error
      sanitize_phone_number(error.message)
      raise
    rescue Faraday::TimeoutError
      retry unless (tries -= 1).zero?
      raise_custom_timeout_error
    end

    DIGITS_TO_PRESERVE = 5

    def raise_custom_timeout_error
      Rails.logger.info(request_data.to_json)
      raise Twilio::REST::RestError.new('timeout', TwilioTimeoutResponse.new)
    end

    def request_data
      last_request = @client.http_client.last_request

      {
        event: 'Twilio Request Timeout',
        url: last_request.url,
        method: last_request.method,
        params: last_request.params,
        headers: last_request.headers,
      }
    end

    def sanitize_phone_number(str)
      str.gsub!(/\+[\d\(\)\- ]+/) do |match|
        digits_preserved = 0

        match.gsub(/\d/) do |chr|
          (digits_preserved += 1) <= DIGITS_TO_PRESERVE ? chr : '#'
        end
      end
    end

    class TwilioTimeoutResponse
      def status_code
        4_815_162_342
      end

      def body
        {}
      end
    end
  end
end
