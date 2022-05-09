class VerifyController < ApplicationController
  include RenderConditionConcern
  include IdvSession

  check_or_render_not_found -> { FeatureManagement.idv_api_enabled? }, only: [:show]

  before_action :redirect_root_path_to_first_step
  before_action :validate_step
  before_action :confirm_two_factor_authenticated
  before_action :confirm_idv_vendor_session_started
  before_action :confirm_profile_has_been_created, if: :first_step_is_personal_key?

  def show
    @app_data = app_data
  end

  private

  def redirect_root_path_to_first_step
    redirect_to idv_app_path(step: first_step) if params[:step].blank?
  end

  def validate_step
    render_not_found if !enabled_steps.include?(params[:step])
  end

  def app_data
    user_session[:idv_api_store_key] ||= Base64.strict_encode64(random_encryption_key)

    {
      base_path: idv_app_path,
      app_name: APP_NAME,
      completion_url: completion_url,
      initial_values: initial_values,
      enabled_step_names: IdentityConfig.store.idv_api_enabled_steps,
      store_key: user_session[:idv_api_store_key],
    }
  end

  def initial_values
    case first_step
    when 'password_confirm'
      { 'userBundleToken' => user_bundle_token }
    when 'personal_key'
      { 'personalKey' => personal_key }
    end
  end

  def first_step
    enabled_steps.detect { |step| step_enabled?(step) }
  end

  def first_step_is_personal_key?
    first_step == 'personal_key'
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

  def confirm_profile_has_been_created
    redirect_to account_url if idv_session.profile.blank?
  end

  def personal_key
    idv_session.personal_key || generate_personal_key
  end

  def generate_personal_key
    cacher = Pii::Cacher.new(current_user, user_session)
    idv_session.profile.encrypt_recovery_pii(cacher.fetch)
  end

  def completion_url
    if session[:sp]
      sign_up_completed_url
    else
      after_sign_in_path_for(current_user)
    end
  end

  def user_bundle_token
    Idv::UserBundleTokenizer.new(
      user: current_user,
      idv_session: idv_session,
    ).token
  end
end
