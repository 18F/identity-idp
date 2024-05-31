# frozen_string_literal: true

class SpHandoffBouncer
  attr_reader :sp_session

  def initialize(sp_session)
    @sp_session = sp_session
  end

  def add_handoff_time!(now = Time.zone.now)
    sp_session[:sp_handoff_start_time] = now
  end

  def bounced?(now = Time.zone.now)
    start_time = sp_session[:sp_handoff_start_time]
    return false if start_time.blank?
    start_time = Time.zone.parse(start_time) if start_time.instance_of?(String)
    now <= (start_time + IdentityConfig.store.sp_handoff_bounce_max_seconds.seconds)
  end
end
