class SmsResponder
  attr_reader :url, :params, :signature

  JOIN_KEYWORDS = %w[join].freeze
  HELP_KEYWORDS = %w[help].freeze
  STOP_KEYWORDS = %w[stop cancel end quit unsubscribe].freeze

  def initialize(url, params, signature)
    @url = url
    @params = params
    @signature = signature
  end

  def call
    return invalid_signature_response unless signature_valid?
    return not_a_valid_keyword_response unless valid_keyword?
    respond_to_sms
    FormResponse.new(success: true, errors: {}, extra: extra_analytics_attributes)
  end

  def signature_valid?
    Twilio::Security::RequestValidator.new(
      Figaro.env.twilio_auth_token,
    ).validate(url, params, signature)
  end

  def valid_keyword?
    (JOIN_KEYWORDS + HELP_KEYWORDS + STOP_KEYWORDS).include?(message_body)
  end

  private

  def respond_to_sms
    if JOIN_KEYWORDS.include?(message_body)
      Telephony.send_join_keyword_response(to: message_from)
    elsif HELP_KEYWORDS.include?(message_body)
      Telephony.send_help_keyword_response(to: message_from)
    elsif STOP_KEYWORDS.include?(message_body)
      Telephony.send_stop_keyword_response(to: message_from)
    end
  end

  def invalid_signature_response
    FormResponse.new(
      success: false,
      errors: { base: 'The inbound Twilio SMS message failed validation' },
      extra: extra_analytics_attributes,
    )
  end

  def not_a_valid_keyword_response
    FormResponse.new(
      success: false,
      errors: { base: 'The message does not need a response' },
      extra: extra_analytics_attributes,
    )
  end

  def successful_response
    FormResponse.new(success: true, errors: {}, extra: extra_analytics_attributes)
  end

  def message_body
    params[:Body].downcase
  end

  def message_from
    params[:From]
  end

  def extra_analytics_attributes
    {
      message_sid: params[:MessageSid],
      from_country: params[:FromCountry],
    }
  end
end
