module Health
  class WorkersController < ApplicationController
    def index
      summary = worker_health_checker.summary

      status = summary.all_healthy? ? :ok : :internal_error

      render json: summary, status: status
    end

    protected

    def worker_health_checker
      @_worker_health_checker ||= WorkerHealthChecker
    end
  end
end
