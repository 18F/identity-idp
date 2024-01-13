module Idv
  class AttemptsApiPlugin < BasePlugin
    on_step_completed :request_letter do |resend_requested|
      tracker = IrsAttemptsApi::Tracker.new
      tracker.idv_gpo_letter_requested(resend: resend_requested)
    end
  end
end
