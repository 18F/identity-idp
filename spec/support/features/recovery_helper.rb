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

  def complete_recovery_steps_before_document_capture_step(user = user_with_2fa)
    complete_recovery_steps_before_upload_step(user)
    click_on t('doc_auth.info.upload_computer_link')
  end

  def complete_recovery_steps_before_ssn_step(user = user_with_2fa)
    complete_recovery_steps_before_document_capture_step(user)
    attach_and_submit_images
  end

  def complete_recovery_steps_before_verify_step(user = user_with_2fa)
    complete_recovery_steps_before_ssn_step(user)
    fill_out_ssn_form_ok
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

  def idv_recovery_document_capture_step
    idv_recovery_step_path(step: :document_capture)
  end

  def idv_recovery_ssn_step
    idv_recovery_step_path(step: :ssn)
  end

  def idv_recovery_verify_step
    idv_recovery_step_path(step: :verify)
  end

  def idv_recovery_verify_wait_step
    idv_recovery_step_path(step: :verify_wait)
  end
end
