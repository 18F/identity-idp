module Db
  module DocAuthLog
    class DropOffRates
      STEPS = %w[welcome upload_option front_image back_image ssn verify_info doc_success phone
                 encrypt personal_key verified].freeze

      def call(start, finish)
        @start = start
        @finish = finish
        generate_report
      end

      private

      attr_reader :start, :finish, :results

      def generate_report
        @results = ["#{start} <= date user starts doc auth < #{finish}\n\n"]
        rates = drop_offs_in_range
        verified_profiles = verified_profiles_in_range
        rates['verified'] = verified_profiles[0]['count']
        results << format("%20s %6s %3s %3s\n", 'step', 'users', '%users', 'dropoff')
        print_report(rates)
      end

      def drop_offs_in_range
        rates = ActiveRecord::Base.connection.execute(drop_offs_query)
        rates[0]
      end

      def verified_profiles_in_range
        query = <<~SQL
          select count(*) from
            (select distinct user_id
             from profiles
             where verified_at is not null and user_id in
               (select user_id from doc_auth_logs
                where '#{start}' <= created_at and created_at < '#{finish}')) as tbl
        SQL
        ActiveRecord::Base.connection.execute(query)
      end

      def drop_offs_query
        <<~SQL
          select count(welcome_view_at) as welcome, count(upload_view_at) as upload_option,
          count(COALESCE(front_image_view_at,mobile_front_image_view_at)) as front_image,
          count(COALESCE(back_image_view_at,mobile_back_image_view_at,capture_mobile_back_image_view_at)) as back_image,
          count(ssn_view_at) as ssn,
          count(verify_view_at) as verify_info,
          count(doc_success_view_at) as doc_success,
          count(verify_phone_view_at) as phone,
          count(encrypt_view_at) as encrypt,
          count(verified_view_at) as personal_key
          from doc_auth_logs where '#{start}' <= created_at and created_at < '#{finish}'
        SQL
      end

      def print_report(rates)
        STEPS.each_with_index do |step, index|
          percent_left = calc_percent_left(rates, step, STEPS[0])
          dropoff = calc_dropoff(rates, STEPS[index + 1], step)
          results << format("%20s %6d %5d%% %6d%%\n", step, rates[step], percent_left, dropoff)
        end
        results << "\n\n"
        results.join
      end

      def calc_percent_left(rec, step, total)
        return 100 unless step && total
        total = rec[total]
        return 100 if total.zero?
        ((rec[step] / total.to_f) * 100.0).round
      end

      def calc_dropoff(rec, step, total)
        return 0 unless step && total
        total = rec[total]
        return 0 if total.zero?
        ((1 - (rec[step] / total.to_f)) * 100.0).round
      end
    end
  end
end
