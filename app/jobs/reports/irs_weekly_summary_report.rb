require 'pry'
require 'csv'

#  goal that we can see dummy data sent to S3 and write the first service class with a data query

module Reports
    class IrsWeeklySummaryReport < BaseReport
      REPORT_NAME = 'irs-weekly-summary-report'
  
      include GoodJob::ActiveJobExtensions::Concurrency

      good_job_control_concurrency_with(
        total_limit: 1,
        key: -> { "#{REPORT_NAME}-#{arguments.first}" },
      )

      def perform(report_date)
         @report_date = report_date
         simple_start = start.strftime '%m-%d-%Y'
         simple_finish = finish.strftime '%m-%d-%Y'
    
        save_report(
          REPORT_NAME + '-' + simple_start + '-' + simple_finish,
          generate_csv,
          extension: 'csv',
        )
        
        # it looks like save report has a predefined bucket where things get saved, while upload_file_to_s3_bucket can be used to define specific buckets (ie. public/private)
        # there is also a ReportMailer for emailing reports 
      end

      private

      def start
        #this needs to be beginning of week : ruby time methods 
        # what day of the week should beginning of week be? 
        @report_date.beginning_of_week 
      end
  
      def finish
        # do we know end of day is the end of the week? if it can be scheduled to be the end of the week? 
        @report_date.end_of_week
      end

      def end_of_month
        @report_date.end_of_month
      end

      # The total number of users registered with Login.gov (ie all users currently in the users table)
      def query_system_demand
        User.count
      end

      # The average age, in months, of all accounts. This would be measured from the account creation date to the last day of the month being reported.
      def query_credential_tenure
        created_at_dates = User.pluck(:created_at)
        time_diff_total = 0;
        created_at_dates.each do |date|
          time_diff_in_seconds = end_of_month.to_time.to_i - date.to_time.to_i
          time_diff_total += time_diff_in_seconds
        end
        binding.pry
        (time_diff_total/created_at_dates.length)/2628288 #number of seconds in a month 
      end

      def generate_csv
        CSV.generate do |csv|
          csv << [
            'data requested',
            'total login.gov',
            'total IRS',
          ]
          [{name: 'System Demand', data: query_system_demand}, {name: 'Credential Tenure', data: query_credential_tenure}].each do |data_row|
            csv << [
              data_row[:name],
              data_row[:data],
              'N/A',
            ]
          end
        end
      end
    end
end