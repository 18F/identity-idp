module Health
  class HealthController < AbstractHealthController
    private

    def health_checker
      checkers = {
        database: DatabaseHealthChecker,
      }
      MultiHealthChecker.new(**checkers)
    end
  end
end
