class RememberDeviceCookie
  COOKIE_ROLE = 'remember_me'.freeze

  attr_reader :user_id, :created_at

  def initialize(user_id:, created_at:)
    @user_id = user_id
    @created_at = created_at
  end

  def self.from_json(json)
    parsed_json = JSON.parse(json)
    check_cookie_role(parsed_json)
    new(
      user_id: parsed_json['user_id'],
      created_at: Time.zone.parse(parsed_json['created_at'])
    )
  end

  private_class_method def self.check_cookie_role(parsed_json)
    role = parsed_json['role']
    return if role == COOKIE_ROLE
    raise "RememberDeviceCookie role '#{role}' did not match '#{COOKIE_ROLE}'"
  end

  def to_json
    {
      user_id: user_id,
      created_at: created_at.iso8601,
      role: COOKIE_ROLE,
      entropy: SecureRandom.base64(32),
    }.to_json
  end

  def valid_for_user?(user)
    return false if user.id != user_id
    return false if user_has_changed_phone?(user)
    return false if expired?
    true
  end

  private

  def expired?
    created_at < Figaro.env.remember_device_expiration_days.to_i.days.ago
  end

  def user_has_changed_phone?(user)
    user.phone_confirmed_at.to_i > created_at.to_i
  end
end
