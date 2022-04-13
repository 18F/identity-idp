class VerifyController < ApplicationController
  include RenderConditionConcern
  include IdvSession

  before_action :confirm_two_factor_authenticated
  before_action :confirm_idv_vendor_session_started
  before_action :confirm_profile_has_been_created

  check_or_render_not_found -> { FeatureManagement.idv_api_enabled? }, only: [:show]

  def show
    @app_data = app_data
  end

  private

  def app_data
    cipher = Encryption::AesCipher.encryption_cipher
    session[:idv_api_store_key] ||= Base64.strict_encode64(cipher.random_key)
    session[:idv_api_store_iv] ||= Base64.strict_encode64(cipher.random_iv)

    {
      base_path: idv_app_root_path,
      app_name: APP_NAME,
      completion_url: completion_url,
      initial_values: { 'personalKey' => personal_key },
      enabled_step_names: IdentityConfig.store.idv_api_enabled_steps,
      store_key: session[:idv_api_store_key],
      store_iv: session[:idv_api_store_iv],
    }
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
end
