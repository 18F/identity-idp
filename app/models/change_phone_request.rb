class ChangePhoneRequest < ApplicationRecord
  belongs_to :user

  def change_phone_link_expired?
    return true unless granted_at
    expired?(granted_at)
  end

  def change_phone_allowed?
    security_answer_correct && !expired?(answered_at)
  end

  private

  def expired?(time)
    env = Figaro.env
    return true if env.reset_device_enabled != 'true'
    (time + env.reset_device_valid_for_hours.to_i * 3600) <= Time.zone.now
  end
end
