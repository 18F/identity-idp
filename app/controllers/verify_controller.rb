class VerifyController < ApplicationController
  include IdvStepConcern
  include IdvSession

  before_action :validate_step
  before_action :confirm_idv_steps_complete
  before_action :confirm_idv_phone_confirmed
  before_action :confirm_two_factor_authenticated
  before_action :confirm_idv_vendor_session_started

  def show
    @app_data = app_data
  end

  private

  def confirm_idv_steps_complete
    return redirect_to(idv_doc_auth_url) unless idv_profile_complete?
    return redirect_to(idv_phone_url) unless idv_address_complete?
  end

  def confirm_idv_phone_confirmed
    return unless idv_session.address_verification_mechanism == 'phone'
    return if idv_session.phone_confirmed?
    redirect_to idv_otp_verification_path
  end

  def validate_step
    render_not_found if params[:step].present? && !enabled_steps.include?(params[:step])
  end

  def app_data
    user_session[:idv_api_store_key] ||= Base64.strict_encode64(random_encryption_key)

    {
      base_path: idv_app_path,
      start_over_url: idv_session_path,
      cancel_url: idv_cancel_path,
      in_person_url: IdentityConfig.store.in_person_proofing_enabled ? idv_in_person_url : nil,
      initial_values: initial_values,
      reset_password_url: forgot_password_url,
      enabled_step_names: IdentityConfig.store.idv_api_enabled_steps,
      store_key: user_session[:idv_api_store_key],
    }
  end

  def initial_values
    case first_step
    when 'password_confirm'
      { 'userBundleToken' => user_bundle_token }
    end
  end

  def first_step
    enabled_steps.detect { |step| step_enabled?(step) }
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

  def idv_profile_complete?
    idv_session.profile_confirmation == true
  end

  def idv_address_complete?
    idv_session.address_mechanism_chosen?
  end
end
