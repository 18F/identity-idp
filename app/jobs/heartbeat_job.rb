class HeartbeatJob < ApplicationJob
  queue_as :default

  def perform
    true
  end
end
