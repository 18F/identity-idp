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
      created_at: Time.zone.parse(parsed_json['created_at']),
    )
  end

  private_class_method def self.check_cookie_role(parsed_json)
    role = parsed_json['role']
    return if role == COOKIE_ROLE
    raise "RememberDeviceCookie role '#{role}' did not match '#{COOKIE_ROLE}'"
  end

  def to_json(*args)
    {
      user_id: user_id,
      created_at: created_at.iso8601,
      role: COOKIE_ROLE,
      entropy: SecureRandom.base64(32),
    }.to_json(*args)
  end

  def valid_for_user?(user:, expiration_interval:)
    return false if user.id != user_id
    remember_device_revoked_at = user.remember_device_revoked_at
    return false if remember_device_revoked_at.present? && revoked?(remember_device_revoked_at)
    return false if expired?(expiration_interval)
    true
  end

  private

  def expired?(interval)
    created_at < interval.ago
  end

  def revoked?(remember_device_revoked_at)
    created_at < remember_device_revoked_at
  end
end
