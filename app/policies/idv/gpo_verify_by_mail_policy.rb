# frozen_string_literal: true

module Idv
  class GpoVerifyByMailPolicy
    attr_reader :gpo_mail

    def initialize(user)
      @user = user
      @gpo_mail = Idv::GpoMail.new(user)
    end

    def resend_letter_available?
      FeatureManagement.gpo_verification_enabled? &&
        !gpo_mail.rate_limited? &&
        !gpo_mail.profile_too_old?
    end

    def send_letter_available?
      FeatureManagement.gpo_verification_enabled? &&
        !gpo_mail.rate_limited?
    end
  end
end
