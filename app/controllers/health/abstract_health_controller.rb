module Health
  class AbstractHealthController < ApplicationController
    def index
      summary = health_checker.check

      render json: summary, status: (summary.healthy? ? :ok : :internal_error)
    end
  end
end
