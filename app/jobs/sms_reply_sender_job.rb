class SmsReplySenderJob < ApplicationJob
  queue_as :sms

  def perform(params)
    send_reply(params)
  end

  private

  def send_reply(params)
    TwilioService::Utils.new.send_sms(params)
  end
end
