class RecoveryCodeGenerator
  def initialize(user, length: 16)
    @user = user
    @length = length
  end

  def create
    user.update!(recovery_code: hashed_code)

    raw_recovery_code
  end

  def valid?(raw_code)
    SCrypt::Password.new(user.recovery_code) == peppered_code(raw_code)
  end

  private

  attr_reader :length, :user

  def peppered_code(raw_code = raw_recovery_code)
    "#{raw_code}#{User.pepper}"
  end

  def hashed_code
    SCrypt::Password.create(peppered_code)
  end

  def raw_recovery_code
    @raw_recovery_code ||= SecureRandom.hex(recovery_code_length / 2)
  end

  def recovery_code_length
    Figaro.env.recovery_code_length.to_i || length
  end
end
