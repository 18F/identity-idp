class CreateOmniauthUser
  include ActiveModel::Model
  include FormEmailValidator

  delegate :email, to: :user

  def user
    @user ||= User.new
  end

  def initialize(email)
    user.email = email
  end

  def persisted?
    true
  end

  def perform
    if valid?
      User.find_or_create_by(email: email) do |user|
        user.update(confirmed_at: Time.current)
      end
    end
  end
end
