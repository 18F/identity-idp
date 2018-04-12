module IdvStepHelper
  def self.included(base)
    base.class_eval { include IdvHelper }
  end

  def start_idv_at_profile_step(user = user_with_2fa)
    sign_in_and_2fa_user(user)
    visit verify_path unless current_path == verify_path
    click_idv_begin
  end

  def complete_idv_steps_before_address_step(user = user_with_2fa)
    start_idv_at_profile_step(user)
    fill_out_idv_form_ok
    click_idv_continue
  end

  def complete_idv_steps_before_phone_step(user = user_with_2fa)
    complete_idv_steps_before_address_step(user)
    click_idv_address_choose_phone
  end
end
