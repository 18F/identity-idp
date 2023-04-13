class PasswordConfirmationForm < PasswordForm
  attr_reader :validate_confirmation

  def initialize(user)
    super(user)
    @validate_confirmation = true
  end
end
