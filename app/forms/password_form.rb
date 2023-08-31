class PasswordForm
  include ActiveModel::Model
  include FormPasswordValidator

  def initialize(user, options = {})
    @user = user
    @validate_confirmation = options.fetch(:validate_confirmation, false)
  end

  def submit(params)
    @password = params[:password]
    @password_confirmation = params[:password_confirmation]
    @request_id = params.fetch(:request_id, '')

    FormResponse.new(success: valid?, errors: errors, extra: extra_analytics_attributes)
  end

  private

  attr_reader :request_id

  def extra_analytics_attributes
    {
      user_id: user.uuid,
      request_id_present: !request_id.empty?,
    }
  end
end
