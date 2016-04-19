class DashboardController < ApplicationController
  include SpRedirect

  include AccountStateChecker
  before_action :confirm_idv_status

  def index
    case current_user.role
    when 'user'
      redirect_to_sp
    when 'tech'
      redirect_to :support
    end
  end

  def confirm_idv_status
    return if !current_user.needs_idv? || session[:declined_quiz]

    redirect_to idp_index_path
  end
end
