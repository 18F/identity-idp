class PersonalKeyLoginOptionPolicy
  def initialize(user)
    @user = user
  end

  def configured?
    user.personal_key.present?
  end

  private

  attr_reader :user
end
