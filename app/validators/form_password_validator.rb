module FormPasswordValidator
  extend ActiveSupport::Concern

  included do
    attr_accessor :password
    attr_reader :user

    validates :password,
              presence: true,
              length: Devise.password_length

    validate :valid_password
  end

  def valid_password
    return if errors[:password].any?
    temp_user = User.new(password: password)
    return if temp_user.valid?
    errors.add :password, temp_user.errors[:password].first
  end
end
