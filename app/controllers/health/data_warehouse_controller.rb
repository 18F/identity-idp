# frozen_string_literal: true

module Health
  class DataWarehouseController < AbstractHealthController
    private

    def health_checker
      DataWarehouseHealthChecker
    end
  end
end
