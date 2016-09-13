class RecoveryCodeGenerator
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
    Devise::Encryptor.digest(User, raw_recovery_code)
  end

  def raw_recovery_code
    @raw_recovery_code ||= SecureRandom.hex(recovery_code_length / 2)
  end

  def recovery_code_length
    Figaro.env.recovery_code_length.to_i || length
  end
end
