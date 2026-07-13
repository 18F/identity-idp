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
    batch_size = ENV['BATCH_SIZE']&.to_i || 10_000
    records_count = without_document_type_requested.count

    logger.info(
      "Found #{records_count} document_capture_sessions to backfill document_type_requested",
    )

    tally = 0
    tally += update_in_batches(
      state_id_card_requested,
      Idp::Constants::DocumentTypes::STATE_ID_CARD,
      logger:,
      records_count:,
      label: 'STATE_ID_CARD',
      batch_size:,
    )
    tally += update_in_batches(
      passport_requested,
      Idp::Constants::DocumentTypes::PASSPORT,
      logger: logger,
      records_count:,
      label: 'PASSPORT',
      batch_size:,
    )

    logger.info("COMPLETE: Updated #{tally}/#{records_count} document_capture_sessions")
  end

  task rollback_backfill_document_type_requested: :environment do |t, _args|
    logger = Logger.new(STDOUT, progname: "[#{t.name}]")
    batch_size = ENV['BATCH_SIZE']&.to_i || 10_000
    records_count = without_document_type_requested.count

    logger.info(
      "Found #{records_count} document_capture_sessions to backfill document_type_requested",
    )

    update_in_batches(
      backfilled_document_type_requested,
      nil,
      logger:,
      records_count:,
      label: 'ROLLBACK',
      batch_size:,
    )
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

  def update_in_batches(scope, document_type_requested, logger:, records_count:, label:, batch_size:)
    tally = 0

    scope.in_batches(of: batch_size, load: false) do |batch|
      with_timeout do
        tally += batch.update_all(document_type_requested:) # rubocop:disable Rails/SkipsModelValidations
      end

      logger.info("commit #{tally}/#{records_count} document_capture_sessions (#{label})")
    end

    tally
  end

  def with_timeout
    timeout_in_seconds = ENV['STATEMENT_TIMEOUT_IN_SECONDS']&.to_i || 30.seconds
    ActiveRecord::Base.transaction do
      quoted_timeout = ActiveRecord::Base.connection.quote(timeout_in_seconds.in_milliseconds)
      ActiveRecord::Base.connection.execute("SET LOCAL statement_timeout = #{quoted_timeout}")
      yield
    end
  end
end
