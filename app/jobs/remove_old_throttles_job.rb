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
      removed_count = write_transaction_with_timeout do
        Throttle.
          where('updated_at < ?', now - (WINDOW + max_window.minutes)).
          or(Throttle.where(updated_at: nil)).
          limit(limit).
          delete_all
      end

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

  def write_transaction_with_timeout(rails_env = Rails.env)
    # rspec-rails's use_transactional_tests does not seem to act as expected when switching
    # connections mid-test, so we just skip for now :[
    return yield if rails_env.test?

    ActiveRecord::Base.transaction do
      # 30 seconds
      quoted_timeout = ActiveRecord::Base.connection.quote(30_000)
      ActiveRecord::Base.connection.execute("SET LOCAL statement_timeout = #{quoted_timeout}")
      yield
    end
  end
end
