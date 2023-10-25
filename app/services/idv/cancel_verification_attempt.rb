# frozen_string_literal: true

module Idv
  class CancelVerificationAttempt
    attr_reader :user

    def initialize(user:)
      @user = user
    end

    def call
      user.profiles.each do |profile|
        if profile.gpo_verification_pending?
          profile.update!(
            active: false,
            deactivation_reason: :verification_cancelled,
            gpo_verification_pending_at: nil,
          )
        end

        if profile.in_person_verification_pending?
          profile.update!(
            active: false,
            deactivation_reason: :verification_cancelled,
            in_person_verification_pending_at: nil,
          )
        end
      end
    end
  end
end
