module ValidEmailParameter
  extend ActiveSupport::Concern

  included do
    append_before_action :check_for_valid_email_param, only: :create
  end

  protected

  def check_for_valid_email_param
    return if email_param[:email].present? && ValidateEmail.mx_valid?(email_param[:email])
    flash[:error] = t('valid_email.validations.email.invalid')
    redirect_to action: :new
  end

  def email_param
    params.require(:user).permit(:email)
  end
end
