# frozen_string_literal: true

class ForgetAllBrowsers
  attr_reader :user, :remember_device_revoked_at

  def initialize(user, remember_device_revoked_at: nil)
    @user = user
    @remember_device_revoked_at = remember_device_revoked_at || Time.zone.now
  end

  def call
    user.update!(remember_device_revoked_at: remember_device_revoked_at)
  end
end
