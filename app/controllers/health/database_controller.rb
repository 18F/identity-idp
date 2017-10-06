module Health
  class DatabaseController < AbstractHealthController
    private

    def health_checker
      DatabaseHealthChecker
    end
  end
end
