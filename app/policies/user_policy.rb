class UserPolicy
  attr_reader :current_user, :model

  def initialize(current_user, model)
    @current_user = current_user
    @user = model
  end

  def index?
    @current_user.admin?
  end

  def show?
    @current_user.admin?
  end

  def update?
    @current_user.admin?
  end

  def edit?
    @current_user.admin?
  end

  def destroy?
    return false if @current_user == @user
    @current_user.admin?
  end

  def reset_password?
    @current_user.admin?
  end

  def tech_reset_password?
    return false if @user.admin? || @user.tech? || !@user.security_questions_enabled?
    @current_user.tech? || @current_user.admin?
  end

  def recover_password?
    @user.role == 'user'
  end
end
