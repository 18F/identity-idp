module SpHandoffBounce
  class IsBounced
    def self.call(session)
      start_time = session[:sp_handoff_start_time]
      return if start_time.blank?
      tz = Time.zone
      start_time = tz.parse(start_time) if start_time.class == String
      duration = Identity::Hostdata.settings.sp_handoff_bounce_max_seconds.to_i.seconds
      tz.now <= (start_time + duration)
    end
  end
end
