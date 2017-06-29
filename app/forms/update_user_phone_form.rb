class UpdateUserPhoneForm
  include ActiveModel::Model
  include FormPhoneValidator

  attr_accessor :phone
  attr_reader :user

  def persisted?
    true
  end

  def initialize(user)
    @user = user
    self.phone = @user.phone
  end

  def submit(params)
    check_phone_change(params)

    FormResponse.new(success: valid?, errors: errors.messages)
  end

  def phone_changed?
    phone_changed == true
  end

  private

  attr_reader :phone_changed

  def check_phone_change(params)
    formatted_phone = params[:phone].phony_formatted(
      format: :international, normalize: :US, spaces: ' '
    )

    return unless formatted_phone != @user.phone

    @phone_changed = true
    self.phone = formatted_phone
  end
end
