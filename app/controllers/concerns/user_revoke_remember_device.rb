module UserRevokeRememberDevice
  def revoke_remember_device
    return if user_session[:signing_up]
    UpdateUser.new(
      user: current_user,
      attributes: { remember_device_revoked_at: Time.zone.now },
    ).call
  end

  def revoke_otp_secret_key
    UpdateUser.new(
      user: current_user,
      attributes: { otp_secret_key: nil},
    ).call
  end
end
