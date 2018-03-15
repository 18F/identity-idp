class RememberDeviceCookie
  attr_reader :user_id, :created_at

  def initialize(user_id:, created_at:)
    @user_id = user_id
    @created_at = created_at
  end

  def self.from_json(json)
    parsed_json = JSON.parse(json)
    new(
      user_id: parsed_json['user_id'],
      created_at: Time.zone.parse(parsed_json['created_at'])
    )
  end

  def to_json
    {
      user_id: user_id,
      created_at: created_at.iso8601,
    }.to_json
  end

  def valid_for_user?(user)
    return false if user.id != user_id
    return false if user.phone_confirmed_at > created_at
    return false if created_at < Figaro.env.remember_device_expiration_days.to_i.days.ago
    true
  end
end
