class AccountsController < ApplicationController
  before_action :confirm_two_factor_authenticated

  layout 'card_wide'

  def show
    analytics.track_event(Analytics::ACCOUNT_VISIT)
    cacher = Pii::Cacher.new(current_user, user_session)

    @view_model = AccountShow.new(
      decrypted_pii: cacher.fetch,
      personal_key: flash[:personal_key],
      decorated_user: current_user.decorate,
    )
  end
end
