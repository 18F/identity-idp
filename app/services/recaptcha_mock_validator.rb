# frozen_string_literal: true

class RecaptchaMockValidator < RecaptchaValidator
  attr_reader :score

  def initialize(score:, **kwargs)
    super(**kwargs)
    @score = score
  end

  private

  def recaptcha_result(_recaptcha_token)
    RecaptchaResult.new(success: true, score:)
  end

  def recaptcha_score_meets_threshold?(score)
    score >= score_threshold
  end
end
