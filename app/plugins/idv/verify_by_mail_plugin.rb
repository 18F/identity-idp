module Idv
  class VerifyByMailPlugin < BasePlugin
    on_step_completed :request_letter do |redirector:, letter_enqueued: nil, **rest|
      if letter_enqueued
        redirector.redirect_to(idv_letter_enqueued_url)
      else
        redirector.redirect_to(idv_enter_password_url)
      end
    end
  end
end
