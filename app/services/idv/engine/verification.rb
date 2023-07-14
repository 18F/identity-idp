module Idv::Engine
  # A Verification holds the IdV status for a single User.
  class Verification
    def initialize(
      valid:
    )
      @valid = valid
    end

    # @returns [Boolean] Whether this identity verification is valid (represents a valid identity).
    def valid?
      !!@valid
    end
  end
end
