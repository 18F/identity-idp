class IdentitiesBackfillJob < ApplicationJob
  # This is a short-term solution to backfill data requiring a table scan.
  # This job can be deleted once it's done.

  queue_as :low

  # Let's give us the option to fine-tune this on the fly
  BATCH_SIZE_KEY = 'IdentitiesBackfillJob.batch_size'.freeze
  SLICE_SIZE_KEY = 'IdentitiesBackfillJob.slice_size'.freeze
  CACHE_KEY = 'IdentitiesBackfillJob.position'.freeze

  def perform
    start_time = Time.zone.now
    max_id = ServiceProviderIdentity.last.id

    (batch_size / slice_size).times.each do |slice_num|
      start_id = position + (slice_size * slice_num)
      next if start_id > max_id
      params = {
        min_id: start_id,
        max_id: start_id + slice_size,
      }.transform_values { |v| ActiveRecord::Base.connection.quote(v) }
      sp_query = format(<<~SQL, params)
        UPDATE identities
        SET last_consented_at = created_at
        WHERE id > %{min_id}
        AND id <= %{max_id}
        AND deleted_at IS NULL
        AND last_consented_at IS NULL
      SQL

      ActiveRecord::Base.connection.execute(sp_query)
      logger.info "Processed #{slice_size} rows starting at row #{start_id}"
    end

    elapsed_time = Time.zone.now - start_time
    logger.info "Finished a full batch of #{batch_size} rows in #{elapsed_time} seconds"

    # If we made it here without error, increment the counter for next time:
    REDIS_POOL.with { |redis| redis.set(CACHE_KEY, position + batch_size) }
  end

  def position
    redis_get(CACHE_KEY, 0)
  end

  def batch_size
    redis_get(BATCH_SIZE_KEY, 500_000)
  end

  def slice_size
    redis_get(SLICE_SIZE_KEY, 10_000)
  end

  def redis_get(key, default)
    (REDIS_POOL.with { |redis| redis.get(key) } || default).to_i
  end
end
