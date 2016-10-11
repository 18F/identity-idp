class RecoveryCodeGenerator
  STRETCHES = 12

  def self.compare(hashed_code, recovery_code)
    return false if hashed_code.blank?
    bcrypt = BCrypt::Password.new(hashed_code)
    password = BCrypt::Engine.hash_secret(recovery_code, bcrypt.salt)
    Devise.secure_compare(password, hashed_code)
  end

  def initialize(user, length: 16)
    @user = user
    @length = length
  end

  def create
    user.update!(recovery_code: hashed_code)

    raw_recovery_code
  end

  private

  attr_reader :length, :user

  def hashed_code
    BCrypt::Password.create(raw_recovery_code, cost: STRETCHES).to_s
  end

  def raw_recovery_code
    @raw_recovery_code ||= SecureRandom.hex(recovery_code_length / 2)
  end

  def recovery_code_length
    Figaro.env.recovery_code_length.to_i || length
  end
end
