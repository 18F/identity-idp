class TwilioSmsService
  attr_accessor :api

  def initialize
    @service = TwilioService.new
    @api = @service.client
  end

  def send_sms(params = {})
    params = params.reverse_merge(from: @service.from_number)
    @api.messages.create(params)
  end
end
