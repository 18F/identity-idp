# frozen_string_literal: true

namespace :document_capture_sessions do
  desc 'Backfill the document_type_requested column.'
  ##
  # Usage:
  #
  # Commit updates to document_capture_sessions defining the document_type_requested column.
  # bundle exec \
  #   rake document_capture_sessions:backfill_document_type_requested
  #
  task backfill_document_type_requested: :environment do |t, _args|
    logger = Logger.new(STDOUT, progname: "[#{t.name}]")
    batch_size = ENV['BATCH_SIZE']&.to_i || 1000
    records_count = without_document_type_requested.count

    with_timeout do
      logger.info(
        "Found #{records_count} document_capture_sessions to backfill document_type_requested",
      )

      tally = 0
      state_id_card_requested.in_batches(of: batch_size) do |batch|
        tally += batch
          .update_all(document_type_requested: Idp::Constants::DocumentTypes::STATE_ID_CARD) # rubocop:disable Rails/SkipsModelValidations

        logger.info("commit #{tally}/#{records_count} document_capture_sessions (STATE_ID_CARD)")
      end

      passport_requested.in_batches(of: batch_size) do |batch|
        tally += batch.update_all(document_type_requested: Idp::Constants::DocumentTypes::PASSPORT) # rubocop:disable Rails/SkipsModelValidations
        logger.info("commit #{tally}/#{records_count} document_capture_sessions (PASSPORT)")
      end

      logger.info("COMPLETE: Updated #{tally}/#{records_count} document_capture_sessions")
    end
  end

  task rollback_backfill_document_type_requested: :environment do |t, _args|
    logger = Logger.new(STDOUT, progname: "[#{t.name}]")
    batch_size = ENV['BATCH_SIZE']&.to_i || 1000
    records_count = without_document_type_requested.count

    with_timeout do
      logger.info(
        "Found #{records_count} document_capture_sessions to backfill document_type_requested",
      )

      backfilled_document_type_requested.in_batches(of: batch_size) do |batch|
        batch.update_all(document_type_requested: nil) # rubocop:disable Rails/SkipsModelValidations
      end
    end
  end

  def without_document_type_requested
    DocumentCaptureSession
      .where.not(passport_status: nil)
      .where(document_type_requested: nil)
  end

  def backfilled_document_type_requested
    DocumentCaptureSession
      .where.not(document_type_requested: nil)
      .where.not(passport_status: nil)
  end

  def passport_requested
    without_document_type_requested.where(passport_status: 'requested')
  end

  def state_id_card_requested
    without_document_type_requested.where(passport_status: 'not_requested')
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
