module IdvStepConcern
  extend ActiveSupport::Concern

  include IdvSession

  included do
    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed
  end

  def confirm_user_has_completed_verify_step
    return if verify_step_complete?

    redirect_to idv_verify_info_url
  end

  def verify_step_complete?
    idv_session.profile_confirmation && idv_session.resolution_successful
  end

  def confirm_user_has_completed_address_step
    return if address_step_completed?

    redirect_to idv_otp_verification_path
  end

  def address_step_completed?
    idv_session.address_verification_mechanism == 'gpo' || phone_user_confirmation_complete?
  end

  def phone_user_confirmation_complete?
    idv_session.vendor_phone_confirmation && idv_session.user_phone_confirmation
  end
end
