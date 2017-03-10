class RecoveryCodeForm
  include ActiveModel::Model

  attr_accessor :code

  def initialize(user, code = [])
    @user = user
    @code = code
  end

  def submit
    @success = valid_recovery_code?

    UpdateUser.new(user: user, attributes: { recovery_code: nil }).call if success

    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  private

  attr_reader :user, :success

  def valid_recovery_code?
    recovery_code_generator = RecoveryCodeGenerator.new(user)
    recovery_code_generator.verify(code)
  end

  def extra_analytics_attributes
    {
      multi_factor_auth_method: 'recovery code',
    }
  end
end
