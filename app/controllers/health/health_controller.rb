# frozen_string_literal: true

module Health
  class HealthController < AbstractHealthController
    private

    def health_checker
      checkers = {
        database: DatabaseHealthChecker,
        # data_warehouse: DataWarehouseHealthChecker,
      }
      MultiHealthChecker.new(**checkers)
    end
  end
end
