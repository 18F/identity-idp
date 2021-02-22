class AnalyticsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    head :ok
  end
end
