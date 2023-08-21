module Idv
  class CancelVerificationAttempt
    attr_reader :user

    def initialize(user:)
      @user = user
    end

    def call
      user.profiles.each do |profile|
        if profile.gpo_verification_pending?
          profile.deactivate_for_verify_by_mail_cancelled
        end

        if profile.in_person_verification_pending?
          profile.deactivate_for_in_person_verification_cancelled
        end
      end
    end
  end
end
