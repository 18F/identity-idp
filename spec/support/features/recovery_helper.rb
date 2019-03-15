module RecoveryHelper
  def complete_recovery_steps_before_recover_step(user = user_with_2fa)
    dc = Recover::CreateRecoverRequest.call(user.id)
    visit idv_recovery_recover_step(dc.request_token)
    dc.request_token
  end

  def idv_recovery_recover_step(token)
    idv_recovery_step_path(step: :recover, token: token)
  end

  def idv_recovery_welcome_step
    idv_recovery_step_path(step: :welcome)
  end
end
