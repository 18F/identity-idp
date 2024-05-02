# frozen_string_literal: true

class RecaptchaMockForm < RecaptchaForm
  attr_reader :score

  def initialize(score:, **kwargs)
    super(**kwargs)
    @score = score
  end

  private

  def recaptcha_result
    RecaptchaResult.new(success: true, score:)
  end
end
