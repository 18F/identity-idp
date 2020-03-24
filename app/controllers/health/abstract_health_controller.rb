module Health
  class AbstractHealthController < ApplicationController
    newrelic_ignore_apdex

    def index
      summary = health_checker.check

      # Add health check summary data to New Relic traces.
      ::NewRelic::Agent.add_custom_attributes(
        health_check_summary: summary.as_json,
      )

      render json: summary, status: (summary.healthy? ? :ok : :internal_error)
    end
  end
end
