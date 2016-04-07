class UserContext
  attr_reader :user, :context

  def initialize(user, context)
    @user = user
    @context = context
  end
end
