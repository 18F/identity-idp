class ResendEmailConfirmationForm
  include ActiveModel::Model
  include FormEmailValidator

  attr_reader :email

  def initialize(params = {})
    @params = params
    self.email = params[:email]
    @request_id = params[:request_id]
  end

  def submit
    @success = valid?
    send_confirmation_email_if_necessary
    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  def user
    @_user ||= (email.presence && User.find_with_email(email)) || NonexistentUser.new
  end

  private

  attr_writer :email
  attr_reader :params, :success, :request_id

  def send_confirmation_email_if_necessary
    return unless valid? && user.persisted? && !user.confirmed?

    user.send_custom_confirmation_instructions(request_id)
  end

  def extra_analytics_attributes
    {
      user_id: user.uuid,
      confirmed: user.confirmed?,
    }
  end
end
