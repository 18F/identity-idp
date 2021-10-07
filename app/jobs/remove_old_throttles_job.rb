class RemoveOldThrottlesJob < ApplicationJob
  queue_as :low

  WINDOW = 30.days.freeze

  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    total_limit: 1,
    key: -> do
      rounded = TimeService.round_time(time: arguments.first, interval: 1.hour)
      "remove-old-throttles-#{rounded.to_i}"
    end,
  )

  discard_on GoodJob::ActiveJobExtensions::Concurrency::ConcurrencyExceededError

  def perform(now, limit: 1000, total_limit: 100_000)
    max_window = Throttle::THROTTLE_CONFIG.map { |_, config| config[:attempt_window] }.max
    total_removed = 0

    loop do
      removed_count = Throttle.
        where('updated_at < ?', now - (WINDOW + max_window.minutes)).
        or(Throttle.where(updated_at: nil)).
        limit(limit).
        delete_all

      total_removed += removed_count

      Rails.logger.info(
        {
          name: 'remove_old_throttles',
          removed_count: removed_count,
          total_removed: total_removed,
          total_limit: total_limit,
        }.to_json,
      )

      break if removed_count.zero?
      break if total_removed >= total_limit
    end
  end
end
