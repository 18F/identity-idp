class PersonalKeyLoginOptionPolicy
  def initialize(user)
    @user = user
  end

  def configured?
    user.encrypted_recovery_code_digest.present?
  end

  private

  attr_reader :user
end
