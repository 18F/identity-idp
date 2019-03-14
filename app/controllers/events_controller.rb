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
  rescue ActiveRecord::RecordNotFound, ActiveModel::RangeError
    render_not_found
  end

  private

  def device_and_events
    user_id = current_user.id
    @events = DeviceTracking::ListDeviceEvents.call(user_id, device_id, 0, EVENTS_PAGE_SIZE).
              map(&:decorate)
    @device = Device.where(user_id: user_id).find(device_id)
  end

  def device_id
    @device_id_param ||= begin
      id = params[:id].try(:to_i)
      id || 0
    end
  end
end
