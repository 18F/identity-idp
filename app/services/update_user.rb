class UpdateUser
  def initialize(user:, attributes:)
    @user = user
    @attributes = attributes
  end

  def call
    user.update!(attributes)
  end

  private

  attr_reader :user, :attributes
end
