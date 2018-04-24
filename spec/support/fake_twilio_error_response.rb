class FakeTwilioErrorResponse
  attr_reader :code

  def initialize(code = '')
    @code = code
  end

  def status_code
    400
  end

  def body
    { 'code' => code }
  end
end
