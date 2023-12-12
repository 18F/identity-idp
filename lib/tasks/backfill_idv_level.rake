namespace :profiles do
  desc 'Backfill the idv_level column.'

  ##
  # Usage:
  #
  # bundle exec rake profiles:backfill_idv_level
  #
  task backfill_idv_level: :environment do |_task, _args|
    with_statement_timeout do
      is_in_person = Profile.where(id: InPersonEnrollment.select(:profile_id))
      is_not_in_person = Profile.where.not(id: InPersonEnrollment.select(:profile_id))
      needs_idv_level = Profile.where(idv_level: nil)

      in_person_and_needs_idv_level = Profile.and(is_in_person).and(needs_idv_level)
      not_in_person_and_needs_idv_level = Profile.and(is_not_in_person).and(needs_idv_level)

      profile_count = in_person_and_needs_idv_level.count + not_in_person_and_needs_idv_level.count
      warn("Found #{profile_count} profile(s) needing backfill")

      count = 0
      in_person_and_needs_idv_level.
        in_batches(of: batch_size) do |batch|
        count += batch.update_all(idv_level: :legacy_in_person) # rubocop:disable Rails/SkipsModelValidations
        report_count(count, profile_count)
      end
      warn("set idv_level for #{count} legacy_in_person profile(s)")

      count = 0
      not_in_person_and_needs_idv_level.
        in_batches(of: batch_size) do |batch|
          count += batch.update_all(idv_level: :legacy_unsupervised) # rubocop:disable Rails/SkipsModelValidations
          report_count(count, profile_count)
        end

      warn("set idv_level for #{count} legacy_unsupervised profile(s)")
    end

    with_statement_timeout do
      warn('Profile counts by idv_level after update:')
      [:legacy_in_person, :legacy_unsupervised, nil].each do |value|
        count = Profile.where(idv_level: value).count
        warn("#{value.inspect}: #{count}")
      end
    end
  end

  def batch_size
    ENV['BATCH_SIZE'] ? ENV['BATCH_SIZE'].to_i : 1000
  end

  def report_count(count, profile_count)
    report_interval = ENV['REPORT_INTERVAL'] ? ENV['REPORT_INTERVAL'].to_i.seconds : 10.seconds
    return if !report_interval

    @last_report ||= Time.zone.now
    return if Time.zone.now - @last_report < report_interval

    percent = sprintf('%.2f', (count / profile_count.to_f) * 100)
    warn("Backfilled #{count} profile(s) (#{percent}%)")

    @last_report = Time.zone.now
  end

  def with_statement_timeout(timeout_in_seconds = nil)
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
