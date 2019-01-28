class EventsController < ApplicationController
  before_action :confirm_two_factor_authenticated
  layout 'card_wide'

  EVENTS_PAGE_SIZE = 25

  def show
    analytics.track_event(Analytics::EVENTS_VISIT)
    @view_model = AccountShow.new(
      decrypted_pii: nil,
      personal_key: nil,
      decorated_user: current_user.decorate,
    )
    device_and_events
    render 'accounts/events/show'
  end

  private

  def device_and_events
    id = params[:id]
    @events = DeviceTracking::ListDeviceEvents.call(current_user, id, 0, EVENTS_PAGE_SIZE).
              map(&:decorate)
    @device = Device.find_by(user_id: current_user.id, id: id.to_i)
  end
end
