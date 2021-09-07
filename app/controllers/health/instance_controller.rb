module Health
  class InstanceController < AbstractHealthController
    private

    def health_checker
      InstanceHealthChecker
    end
  end
end
