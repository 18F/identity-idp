module Idv::Engine
  class Verification
    def initialize(data)
      @data = data
    end

    def identity_verified?
      !!@data[:identity_verified?]
    end

    def user_has_started_idv?
      @data[:user_has_started_idv?]
    end

    def user_has_consented_to_share_pii?
      @data[:user_has_consented_to_share_pii?]
    end
  end
end
