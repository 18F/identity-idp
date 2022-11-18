class IdentitiesBackfillJob
  # This is a short-term solution to backfill data requiring a table scan.
  # This job can be deleted once it's done.

  queue_as :low

  # Let's give us the option to fine-tune this on the fly
  BATCH_SIZE_KEY = 'IdentitiesBackfillJob.batch_size'.freeze
  CACHE_KEY = 'IdentitiesBackfillJob.position'.freeze

  def perform
    position = Rails.cache.read(CACHE_KEY).to_i || 0
    batch_size = Rails.cache.read(BATCH_SIZE_KEY).to_i || 500_000

    # max id today is in the 184M range
    return true if position >= 185_000_000

    sp_query = <<~SQL
UPDATE identities
SET last_consented_at = created_at
WHERE id > #{position}
AND last_consented_at IS NULL
AND deleted_at IS NOT NULL
LIMIT #{batch_size}
    SQL

    ActiveRecord::Base.connection.execute(sp_query)

    agency_query = <<~SQL
UPDATE agency_identities
SET consented=true
WHERE id > #{position}
LIMIT #{batch_size}
    SQL

    ActiveRecord::Base.connection.execute(agency_query)

    # If we made it here, nothing blew up; increment the counter for next time
    Rails.cache.write(CACHE_KEY, position + batch_size)
  end
end
