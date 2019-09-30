module SpRedirectBounce
  class IsBounced
    def self.call(session)
      start_time = session[:sp_redirect_start_time]
      return if start_time.blank?
      Time.zone.now < Figaro.env.sp_redirect_bounce_max_seconds.to_i.seconds + start_time
    end
  end
end
