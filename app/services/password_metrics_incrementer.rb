class PasswordMetricsIncrementer
  def initialize(password)
    @password = password
  end

  def increment_password_metrics
    PasswordMetric.increment(:length, password.length)
    PasswordMetric.increment(:guesses_log10, guesses_log10)
  end

  private

  attr_reader :password

  # Disable :reek:UncommunicativeMethodName b/c this method name ends with a number
  def guesses_log10
    Zxcvbn::Tester.new.test(password).guesses_log10.round(1)
  end
end
