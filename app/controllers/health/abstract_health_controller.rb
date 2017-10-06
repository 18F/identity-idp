module Health
  class AbstractHealthController < ApplicationController
    newrelic_ignore_apdex

    def index
      summary = health_checker.check

      render json: summary, status: (summary.healthy? ? :ok : :internal_error)
    end
  end
end
