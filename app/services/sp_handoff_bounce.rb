class SpHandoffBounce
  def self.is_bounced?(session)
    start_time = session[:sp_handoff_start_time]
    return if start_time.blank?
    tz = Time.zone
    start_time = tz.parse(start_time) if start_time.class == String
    tz.now <= (start_time + AppConfig.env.sp_handoff_bounce_max_seconds.to_i.seconds)
  end

  def self.add_handoff_time_to_session(session)
    session[:sp_handoff_start_time] = Time.zone.now
  end
end
