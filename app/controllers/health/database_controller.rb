module Health
  class DatabaseController < ApplicationController
    def index
      summary = DatabaseHealthChecker.check

      render json: summary, status: (summary.healthy ? :ok : :internal_error)
    end
  end
end
