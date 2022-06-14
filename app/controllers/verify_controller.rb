class VerifyController < ApplicationController
  include RenderConditionConcern
  include IdvSession

  check_or_render_not_found -> { FeatureManagement.idv_api_enabled? }, only: [:show]

  before_action :validate_step
  before_action :confirm_two_factor_authenticated
  before_action :confirm_idv_vendor_session_started

  def show
    @app_data = app_data
  end

  private

  def validate_step
    render_not_found if params[:step].present? && !enabled_steps.include?(params[:step])
  end

  def app_data
    user_session[:idv_api_store_key] ||= Base64.strict_encode64(random_encryption_key)

    {
      base_path: idv_app_path,
      start_over_url: idv_session_path,
      cancel_url: idv_cancel_path,
      initial_values: initial_values,
      reset_password_url: forgot_password_url,
      enabled_step_names: IdentityConfig.store.idv_api_enabled_steps,
      store_key: user_session[:idv_api_store_key],
    }
  end

  def initial_values
    { 'userBundleToken' => user_bundle_token }
  end

  def enabled_steps
    IdentityConfig.store.idv_api_enabled_steps
  end

  def step_enabled?(step)
    enabled_steps.include?(step)
  end

  def random_encryption_key
    Encryption::AesCipher.encryption_cipher.random_key
  end

  def user_bundle_token
    Idv::UserBundleTokenizer.new(
      user: current_user,
      idv_session: idv_session,
    ).token
  end
end
