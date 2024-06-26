# frozen_string_literal: true
namespace :in_person_enrollments do
  desc 'Backfill the sponsor_id column.'

  ##
  # Usage:
  #
  # bundle exec rake in_person_enrollments:backfill_sponsor_id
  #
  task backfill_sponsor_id: :environment do |_task, _args|
    with_timeout do
      ipp_sponsor_id = IdentityConfig.store.usps_ipp_sponsor_id.to_i
      enrollments_without_sponsor_id = InPersonEnrollment.where(sponsor_id: nil)
      enrollments_without_sponsor_id_count = enrollments_without_sponsor_id.count

      warn("Found #{enrollments_without_sponsor_id_count} in_person_enrollments needing backfill")

      tally = 0
      enrollments_without_sponsor_id.in_batches(of: batch_size) do |batch|
        tally += batch.update_all(sponsor_id: ipp_sponsor_id) # rubocop:disable Rails/SkipsModelValidations
        warn("set sponsor_id for #{tally} in_person_enrollments")
      end
      warn("COMPLETE: Updated #{tally} in_person_enrollments")

      enrollments_without_sponsor_id = InPersonEnrollment.where(sponsor_id: nil)
      enrollments_without_sponsor_id_count = enrollments_without_sponsor_id.count
      warn("#{enrollments_without_sponsor_id_count} enrollments without a sponsor id")
    end
  end

  def batch_size
    ENV['BATCH_SIZE'] ? ENV['BATCH_SIZE'].to_i : 1000
  end

  def with_timeout
    timeout_in_seconds ||= if ENV['STATEMENT_TIMEOUT_IN_SECONDS']
                             ENV['STATEMENT_TIMEOUT_IN_SECONDS'].to_i.seconds
                          else
                            60.seconds
                          end
    ActiveRecord::Base.transaction do
      quoted_timeout = ActiveRecord::Base.connection.quote(timeout_in_seconds.in_milliseconds)
      ActiveRecord::Base.connection.execute("SET statement_timeout = #{quoted_timeout}")
      yield
    end
  end
end
