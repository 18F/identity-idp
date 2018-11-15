class RecoveryCodeVerificationForm
  include ActiveModel::Model

  def initialize(user)
    @user = user
    @recovery_code = ''
  end

  def submit
    FormResponse.new(success: valid_recovery_code?, errors: {}, extra: extra_analytics_attributes)
  end

  attr_reader :user, :recovery_code

  def valid_recovery_code?
    code = params[:recovery_code]
    exists = user.recovery_code_configurations.exists(code: code)
    return false unless exists
    @code[:used] = true
  end

  def extra_analytics_attributes
    {
        multi_factor_auth_method: 'recovery_code',
    }
  end
end
