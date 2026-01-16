# frozen_string_literal: true

namespace :in_person_enrollments do
  desc 'Backfill the document_type column.'
  ##
  # Usage:
  #
  # Commit updates to enrollments. DOC_TYPE defaults to 'state_id'
  # bundle exec \
  #   rake in_person_enrollments:backfill_document_type [DOC_TYPE='state_id'|'passport_book']
  #
  task backfill_document_type: :environment do |t, _args|
    logger = Logger.new(STDOUT, progname: "[#{t.name}]")
    document_type = (ENV['DOC_TYPE'] || InPersonEnrollment::DOCUMENT_TYPE_STATE_ID).to_sym
    batch_size = ENV['BATCH_SIZE']&.to_i || 1000

    with_timeout do
      records = enrollments_without_document_type
      records_count = records.count

      logger.info("Found #{records_count} in_person_enrollments needing backfill")

      tally = 0
      records.in_batches(of: batch_size) do |batch|
        tally += batch.update_all(document_type:) # rubocop:disable Rails/SkipsModelValidations
        logger.info("commit document_type for #{tally}/#{records_count} in_person_enrollments")
      end

      logger.info("COMPLETE: Updated #{tally}/#{records_count} in_person_enrollments")

      records_count = enrollments_without_document_type.count
      logger.info("#{records_count} new enrollments without a document type")
    end
  end

  def enrollments_without_document_type
    InPersonEnrollment
      .where(document_type: nil)
      .where.not(
        status: InPersonEnrollment::STATUS_ESTABLISHING,
      )
  end

  def with_timeout
    timeout_in_seconds = ENV['STATEMENT_TIMEOUT_IN_SECONDS']&.to_i || 60.seconds
    ActiveRecord::Base.transaction do
      quoted_timeout = ActiveRecord::Base.connection.quote(timeout_in_seconds.in_milliseconds)
      ActiveRecord::Base.connection.execute("SET LOCAL statement_timeout = #{quoted_timeout}")
      yield
    end
  end
end
