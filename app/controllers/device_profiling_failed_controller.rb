# frozen_string_literal: true

class DeviceProfilingFailedController < ApplicationController
  def show
    analytics.device_profiling_failed_visited
    sign_out
  end
end
