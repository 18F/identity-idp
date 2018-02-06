class PasswordForm
  include ActiveModel::Model
  include FormPasswordValidator

  def initialize(user)
    @user = user
  end

  def submit(params)
    submitted_password = params[:password]
    @request_id = params.fetch(:request_id, '')

    self.password = submitted_password

    FormResponse.new(success: valid?, errors: errors.messages, extra: extra_analytics_attributes)
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
