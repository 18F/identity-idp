class DashboardController < ApplicationController
  include SpRedirect

  before_action :confirm_two_factor_authenticated

  def index
    case current_user.role
    when 'user'
      redirect_to_sp
    when 'tech'
      redirect_to :support
    end
  end
end
