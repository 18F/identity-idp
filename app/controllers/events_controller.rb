class EventsController < ApplicationController
  before_action :confirm_two_factor_authenticated

  layout 'card_wide'

  def show
    analytics.track_event(Analytics::ACCOUNT_VISIT)
    @view_model = AccountShow.new(
      decrypted_pii: nil,
      personal_key: nil,
      decorated_user: current_user.decorate,
    )
    @events = DeviceTracking::ListDeviceEvents.call(current_user, params[:id]).map(&:decorate)
    render 'accounts/events/show'
  end
end
