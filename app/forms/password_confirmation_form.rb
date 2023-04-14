class PasswordConfirmationForm < PasswordForm
  attr_reader :validate_confirmation

  def initialize(user)
    super
    @validate_confirmation = true
  end
end
