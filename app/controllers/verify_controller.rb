class VerifyController < ApplicationController
  include RenderConditionConcern

  check_or_render_not_found -> { FeatureManagement.idv_api_enabled? }, only: [:show]

  before_action :validate_step
  before_action :confirm_two_factor_authenticated
  before_action :confirm_idv_vendor_session_started
  before_action :confirm_profile_has_been_created, if: :first_step_is_personal_key?

  def show
    @app_data = app_data
  end

  private

  def validate_step
    render_not_found if params[:step].present? && !enabled_steps.include?(params[:step])
  end

  def app_data
    {
      base_path: idv_app_path,
      start_over_url: idv_session_path,
      cancel_url: idv_cancel_path,
      completion_url: completion_url,
      initial_values: initial_values,
      enabled_step_names: IdentityConfig.store.idv_api_enabled_steps,
      store_key: user_session[:idv_api_store_key],
    }
  end
end
