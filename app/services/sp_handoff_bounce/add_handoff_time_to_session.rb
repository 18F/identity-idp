# frozen_string_literal: true

module SpHandoffBounce
  class AddHandoffTimeToSession
    def self.call(session)
      session[:sp_handoff_start_time] = Time.zone.now
    end
  end
end
