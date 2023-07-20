module Idv::Engine
  class Base
    include Events

    def initialize
    end

    # @return [Verification] The current verification.
    def verification
      @verification ||= build_verification
    end

    protected

    def build_verification
      raise 'build_verification not implemented'
    end

    def handle_event(event_name, payload = nil)
      invalidate_cache!
      invoke_handlers(event_name, payload)
    end

    def invalidate_cache!
      @verification = nil
    end
  end
end
