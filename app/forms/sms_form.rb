class SmsForm
  include ActiveModel::Model

  validate :validate_message

  def initialize(message)
    @message = message
  end

  def submit
    success = valid?

    FormResponse.new(
      success: success,
      errors: errors.messages,
      extra: message.extra_analytics_attributes
    )
  end

  private

  attr_reader :message

  def validate_message
    return if message.valid?
    errors.add :base, :twilio_inbound_sms_invalid
  end
end
