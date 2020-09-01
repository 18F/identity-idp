class AccountsController < ApplicationController
  include RememberDeviceConcern
  before_action :confirm_two_factor_authenticated

  layout 'account_side_nav'

  def show
    analytics.track_event(Analytics::ACCOUNT_VISIT)
    cacher = Pii::Cacher.new(current_user, user_session)
    @view_model = AccountShow.new(
      decrypted_pii: cacher.fetch,
      personal_key: flash[:personal_key],
      decorated_user: current_user.decorate,
      locked_for_session: pii_locked_for_session?(current_user),
    )
  end

  def connected_accounts
    cacher = Pii::Cacher.new(current_user, user_session)
    @view_model = AccountShow.new(
      decrypted_pii: cacher.fetch,
      personal_key: flash[:personal_key],
      decorated_user: current_user.decorate,
      locked_for_session: pii_locked_for_session?(current_user),
    )
  end

  def history
    cacher = Pii::Cacher.new(current_user, user_session)
    @view_model = AccountShow.new(
      decrypted_pii: cacher.fetch,
      personal_key: flash[:personal_key],
      decorated_user: current_user.decorate,
      locked_for_session: pii_locked_for_session?(current_user),
    )
  end

  def two_factor_authentication
    cacher = Pii::Cacher.new(current_user, user_session)
    @view_model = AccountShow.new(
      decrypted_pii: cacher.fetch,
      personal_key: flash[:personal_key],
      decorated_user: current_user.decorate,
      locked_for_session: pii_locked_for_session?(current_user),
    )
  end
end
