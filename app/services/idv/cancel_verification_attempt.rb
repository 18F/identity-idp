module Idv
  class CancelVerificationAttempt
    attr_reader :user

    def initialize(user:)
      @user = user
    end

    def call
      user.profiles.gpo_verification_pending.each do |profile|
        profile.update!(
          active: false,
          deactivation_reason: :verification_cancelled,
        )
      end
    end
  end
end
