# frozen_string_literal: true

module Idv
  class GpoVerifyByMailPolicy
    def initialize(user)
      @user = user
      @gpo_mail = Idv::GpoMail.new(user)
    end

    def gpo_available_for_user?
      FeatureManagement.gpo_verification_enabled? &&
        !@gpo_mail.rate_limited? &&
        !@gpo_mail.profile_too_old?
    end
  end
end
