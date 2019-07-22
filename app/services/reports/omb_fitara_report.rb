module Reports
  class OmbFitaraReport
    MOST_RECENT_MONTHS_COUNT = 2
    S3_BUCKET = Figaro.env.omb_fitara_bucket
    S3_FILENAME = Figaro.env.omb_fitara_filename

    def call
      Aws::S3::Resource.new.bucket(S3_BUCKET).object(S3_FILENAME).put(
        body: results_json, acl: 'private', content_type: 'application/json',
      )
    end

    private

    def results_json
      month, year = current_month
      counts = []
      MOST_RECENT_MONTHS_COUNT.times do
        count = count_for_month(month, year)
        counts << { month: "#{year}#{month}", count: count }
        month, year = previous_month(month, year)
      end
      { counts: counts }.to_json
    end

    def count_for_month(month, year)
      start = "#{year}-#{month}-01 00:00:00"
      month, year = next_month(month, year)
      finish = "#{year}-#{month}-01 00:00:00"
      RangeRegisteredCount.call(start, finish)
    end

    def current_month
      today = Time.zone.today
      [today.strftime('%m').to_i, today.strftime('%Y').to_i]
    end

    def next_month(month, year)
      month += 1
      if month > 12
        month = 1
        year += 1
      end
      [month, year]
    end

    def previous_month(month, year)
      month -= 1
      if month.zero?
        month = 12
        year -= 1
      end
      [month, year]
    end
  end
end
