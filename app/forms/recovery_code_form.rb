class RecoveryCodeForm
  def initialize(user, code)
    @user = user
    @code = code
  end

  def submit
    @success = valid_recovery_code?

    user.update!(recovery_code: nil) if @success

    result
  end

  private

  attr_reader :user, :code, :success

  def valid_recovery_code?
    RecoveryCodeGenerator.new(user).valid?(code)
  end

  def result
    {
      success?: success
    }
  end
end
