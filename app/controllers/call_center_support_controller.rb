class CallCenterSupportController < ApplicationController
  before_action :confirm_two_factor_authenticated
  before_action :verify_authorized

  layout 'card_wide'

  def index; end

  def show
    user = User.find_by(uuid: params[:uuid])
    return redirect_to support_url, alert: 'User not found' unless user
    @view_model = AccountShow.new(
      decrypted_pii: nil,
      personal_key: nil,
      decorated_user: user.decorate
    )
    render locals: { user: user }
  end

  def search
    user = User.find_with_email(params[:email])
    if user
      redirect_to support_user_url(user.uuid)
    else
      flash.now[:error] = 'User not found.'
      render :index
    end
  end

  private

  def verify_authorized
    return if current_user.admin? || current_user.tech?
    redirect_to root_url, alert: "You don't have access rights to this page."
  end
end
