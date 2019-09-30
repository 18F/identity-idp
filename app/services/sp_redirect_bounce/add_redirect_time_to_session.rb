module SpRedirectBounce
  class AddRedirectTimeToSession
    def self.call(session)
      session[:sp_redirect_start_time] = Time.zone.now
    end
  end
end
