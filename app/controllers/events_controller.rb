class EventsController < ApplicationController
  include RememberDeviceConcern
  before_action :confirm_two_factor_authenticated
  layout 'no_card'

  EVENTS_PAGE_SIZE = 25

  def show
    analytics.events_visit
    @presenter = AccountShowPresenter.new(
      decrypted_pii: nil,
      personal_key: nil,
      sp_session_request_url: sp_session_request_url_with_updated_params,
      sp_name: decorated_session.sp_name,
      decorated_user: current_user.decorate,
      locked_for_session: pii_locked_for_session?(current_user),
    )
    device_and_events
  rescue ActiveRecord::RecordNotFound, ActiveModel::RangeError
    render_not_found
  end

  private

  def device_and_events
    user_id = current_user.id
    device = Device.where(user_id: user_id).find(device_id)
    return if !device

    @events = Event.where(user_id: user_id, device_id: device.id).order(created_at: :desc).
      limit(EVENTS_PAGE_SIZE).
      map(&:decorate)
    @device = device.decorate
  end

  def device_id
    @device_id ||= begin
      id = params[:id].try(:to_i)
      id || 0
    end
  end
end
