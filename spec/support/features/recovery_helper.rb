module RecoveryHelper
  def complete_recovery_steps_before_recover_step(user = user_with_2fa)
    dc = Recover::CreateRecoverRequest.call(user.id)
    visit idv_recovery_recover_step(dc.request_token)
    dc.request_token
  end

  def complete_recovery_steps_before_overview_step(user = user_with_2fa)
    complete_recovery_steps_before_recover_step(user)
    click_idv_continue
  end

  def complete_recovery_steps_before_upload_step(user = user_with_2fa)
    complete_recovery_steps_before_overview_step(user)
    find('input[name="ial2_consent_given"]').set(true)
    click_on t('recover.buttons.continue')
  end

  def complete_recovery_steps_before_front_image_step(user = user_with_2fa)
    complete_recovery_steps_before_upload_step(user)
    click_on t('doc_auth.buttons.use_computer')
  end

  def complete_recovery_steps_before_back_image_step(user = user_with_2fa)
    complete_recovery_steps_before_front_image_step(user)
    mock_assure_id_ok
    attach_image
    click_idv_continue
  end

  def complete_recovery_steps_before_ssn_step(user = user_with_2fa)
    complete_recovery_steps_before_back_image_step(user)
    attach_image
    click_idv_continue
  end

  def complete_recovery_steps_before_verify_step(user = user_with_2fa)
    complete_recovery_steps_before_ssn_step(user)
    fill_out_ssn_form_ok
    click_idv_continue
  end

  def complete_recovery_steps_before_doc_success_step(user = user_with_2fa)
    complete_recovery_steps_before_verify_step(user)
    click_idv_continue
  end

  def idv_recovery_recover_step(token)
    idv_recovery_step_path(step: :recover, token: token)
  end

  def idv_recovery_overview_step
    idv_recovery_step_path(step: :overview)
  end

  def idv_recovery_upload_step
    idv_recovery_step_path(step: :upload)
  end

  def idv_recovery_front_image_step
    idv_recovery_step_path(step: :front_image)
  end

  def idv_recovery_back_image_step
    idv_recovery_step_path(step: :back_image)
  end

  def idv_recovery_ssn_step
    idv_recovery_step_path(step: :ssn)
  end

  def idv_recovery_verify_step
    idv_recovery_step_path(step: :verify)
  end

  def idv_recovery_success_step
    idv_recovery_step_path(step: :doc_success)
  end

  def idv_recovery_fail_step
    idv_recovery_step_path(step: :recover_fail)
  end
end
