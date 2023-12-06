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

      # rubocop:disable Rails/SkipsModelValidations
      count = Profile.and(is_in_person).and(needs_idv_level).
        update_all(idv_level: :legacy_in_person)
      warn("set idv_level for #{count} legacy_in_person profile(s)")

      count = Profile.and(is_not_in_person).and(needs_idv_level).
        update_all(idv_level: :legacy_unsupervised)
      warn("set idv_level for #{count} legacy_unsupervised profile(s)")
      # rubocop:enable Rails/SkipsModelValidations
    end

    with_statement_timeout do
      warn('Profile counts by idv_level after update:')
      [:legacy_in_person, :legacy_unsupervised, nil].each do |value|
        count = Profile.where(idv_level: value).count
        warn("#{value.inspect}: #{count}")
      end
    end
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
