class TechSupportPolicy < Struct.new(:user, :tech_support)
  def index?
    user.admin? || user.tech?
  end

  def search?
    user.admin? || user.tech?
  end

  def show?
    user.admin? || user.tech?
  end

  def reset?
    user.admin? || user.tech?
  end
end
