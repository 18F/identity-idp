class TwoFactorSetupForm
  include ActiveModel::Model
  include FormMobileValidator

  attr_accessor :mobile

  def initialize(user)
    @user = user
  end

  def submit(params)
    formatted_mobile = params[:mobile].phony_formatted(
      format: :international, normalize: :US, spaces: ' ')
    self.mobile = formatted_mobile

    if valid?
      @user.update(mobile: mobile)
    else
      false
    end
  end
end
