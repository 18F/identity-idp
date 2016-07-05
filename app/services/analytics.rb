require 'staccato/adapter/validate'
require 'staccato/adapter/logger'

class Analytics
  TRACKER = if Rails.env.test?
              Staccato.tracker(nil)
            else
              Staccato.tracker('UA-48605964-44', nil, ssl: true)
            end

  attr_reader :backend

  def initialize(user, request_attributes)
    @user = user
    @backend = TRACKER
    @request_attributes = request_attributes
  end

  def track_event(event, subject = user)
    backend.event(common_options.merge(action: event, user_id: subject.uuid))
  end

  def track_anonymous_event(event, attribute = nil)
    backend.event(common_options.merge(action: event, value: attribute))
  end

  private

  attr_reader :user

  def common_options
    @common_options ||= @request_attributes.merge(
      anonymize_ip: true
    )
  end
end
