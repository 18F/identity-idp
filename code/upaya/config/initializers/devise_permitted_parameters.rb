module DevisePermittedParameters
  extend ActiveSupport::Concern

  included do
    before_filter :configure_permitted_parameters
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.for(:account_update) <<
      [:current_password, :email, :mobile, :password, :password_confirmation,
       :second_factor_confirmed_at, second_factor_ids: []]
  end
end

DeviseController.send :include, DevisePermittedParameters
