class TwilioVoiceService
  attr_accessor :api

  def initialize
    @service = TwilioService.new
    @api = @service.client
  end

  def place_call(params = {})
    params = params.reverse_merge(from: @service.from_number)
    @api.calls.create(params)
  end
end
