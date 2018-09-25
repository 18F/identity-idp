module Health
  class HealthController < AbstractHealthController
    private

    def health_checker
      checkers = {
        database: DatabaseHealthChecker,
        account_reset: AccountResetHealthChecker,
      }
      MultiHealthChecker.new(**checkers)
    end
  end
end
