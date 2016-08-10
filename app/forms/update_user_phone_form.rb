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
    formatted_phone = params[:phone].phony_formatted(
      format: :international, normalize: :US, spaces: ' '
    )

    if formatted_phone != @user.phone
      @phone_changed = true
      self.phone = formatted_phone
    end

    valid?
  end

  def phone_changed?
    @phone_changed == true
  end
end
