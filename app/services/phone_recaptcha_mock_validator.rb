class PhoneRecaptchaMockValidator < PhoneRecaptchaValidator
  attr_reader :score

  def initialize(score:, **kwargs)
    super(**kwargs)
    @score = score
  end

  private

  def validator
    @validator ||= RecaptchaMockValidator.new(score:, score_threshold:, analytics:)
  end
end
