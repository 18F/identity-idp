class ApplicationPolicy
  def initialize(user, record)
    fail Pundit::NotAuthorizedError, 'must be logged in' unless user
    @user = user
    @record = record
  end
end
