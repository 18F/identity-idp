class RecoveryCodeForm
  def initialize(user, code)
    @user = user
    @code = code
  end

  def submit
    @success = valid_recovery_code?

    UpdateUser.new(user: user, attributes: { recovery_code: nil }).call if success

    result
  end

  private

  attr_reader :user, :code, :success

  def valid_recovery_code?
    recovery_code_generator = RecoveryCodeGenerator.new(user)
    recovery_code_generator.verify(code)
  end

  def result
    {
      success: success,
    }
  end
end
