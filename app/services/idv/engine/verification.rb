module Idv::Engine
  # A Verification holds the IdV status for a single User.
  class Verification
    def initialize(
      valid:,
      user_has_started: nil
    )
      @user_has_started = user_has_started
      @valid = valid
    end

    def user_has_started?
      !!@user_has_started
    end

    # @returns [Boolean] Whether this identity verification is valid (represents a valid identity).
    def valid?
      !!@valid
    end
  end
end
