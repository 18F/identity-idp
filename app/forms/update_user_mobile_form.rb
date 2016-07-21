class UpdateUserMobileForm
  include ActiveModel::Model
  include FormMobileValidator

  attr_accessor :mobile
  attr_reader :user

  def persisted?
    true
  end

  def initialize(user)
    @user = user
    self.mobile = @user.mobile
  end

  def submit(params)
    formatted_mobile = params[:mobile].phony_formatted(
      format: :international, normalize: :US, spaces: ' '
    )

    if formatted_mobile != @user.mobile
      @mobile_changed = true
      self.mobile = formatted_mobile
    end

    valid?
  end

  def mobile_changed?
    @mobile_changed == true
  end
end
