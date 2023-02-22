class RecaptchaMockValidator < RecaptchaValidator
  RecaptchaResponse = Struct.new(:success, :score, keyword_init: true) do
    def body
      {
        'success' => true,
        'challenge_ts' => Time.zone.now.iso8601,
        'hostname' => Identity::Hostdata.domain,
        'error-codes' => [],
        'score' => score,
      }
    end
  end

  attr_reader :score

  def initialize(score:, **kwargs)
    super(**kwargs)
    @score = score
  end

  private

  def recaptcha_response(_recaptcha_token)
    RecaptchaResponse.new(score:)
  end
end
