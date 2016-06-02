class TwoFactorSetupForm
  include ActiveModel::Model
  include FormMobileValidator

  attr_accessor :mobile

  def initialize(user)
    @user = user
  end

  def submit(params)
    formatted_mobile = params[:mobile].phony_formatted(
      format: :international, normalize: :US, spaces: ' '
    )
    self.mobile = formatted_mobile

    @user.update(mobile: mobile)

    valid_form?
  end

  def valid_form?
    valid? && !mobile_taken?
  end

  def mobile_taken?
    @mobile_taken == true
  end
end
