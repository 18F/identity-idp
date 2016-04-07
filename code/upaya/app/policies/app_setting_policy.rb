class AppSettingPolicy
  attr_reader :current_user, :model

  def initialize(current_user, _model)
    @current_user = current_user
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
    false
  end

  def create?
    @current_user.admin?
  end

  def new?
    @current_user.admin?
  end
end
