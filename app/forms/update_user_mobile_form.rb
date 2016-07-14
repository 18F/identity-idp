class UpdateUserMobileForm
  include ActiveModel::Model
  include FormMobileValidator

  attr_accessor :mobile

  def persisted?
    true
  end

  def initialize(user)
    @user = user
    self.mobile = @user.mobile
  end

  def submit(params)
    set_attributes(params)

    if valid_form?
      @user.update(params.merge!(mobile: mobile))
    else
      process_errors(params)
    end
  end

  def valid_form?
    valid? && !mobile_taken?
  end

  def mobile_taken?
    @mobile_taken == true
  end

  private

  def set_attributes(params)
    formatted_mobile = params[:mobile].phony_formatted(
      format: :international, normalize: :US, spaces: ' '
    )

    self.mobile = formatted_mobile if formatted_mobile != @user.mobile
  end

  def process_errors(params)
    # To prevent discovery of existing phone numbers, we check
    # to see if the only errors are "already taken" errors, and if so, we
    # act as if the user update was successful.
    if mobile_taken? && valid?
      send_notifications
      @user.update(params.merge!(mobile: mobile))
      return true
    end

    false
  end

  def send_notifications
    SmsSenderExistingMobileJob.perform_later(mobile) if mobile_taken?
  end
end
