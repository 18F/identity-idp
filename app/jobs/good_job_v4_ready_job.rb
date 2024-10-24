# frozen_string_literal: true

class GoodJobV4ReadyJob < ApplicationJob
  queue_as :default

  def perform
    IdentityJobLogSubscriber.new.logger.info(
      {
        name: 'good_job_v4_ready',
        ready: GoodJob.v4_ready?,
      }.to_json,
    )

    true
  end
end
