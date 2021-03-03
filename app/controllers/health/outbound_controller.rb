module Health
  # Checks outbound network connections
  class OutboundController < AbstractHealthController
    private

    def health_checker
      OutboundHealthChecker
    end
  end
end
