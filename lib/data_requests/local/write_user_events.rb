# frozen_string_literal: true

require 'csv'

module DataRequests
  module Local
    class WriteUserEvents
      attr_reader :user_report, :output_dir, :requesting_issuer_uuid

      def initialize(user_report, output_dir, requesting_issuer_uuid)
        @user_report = user_report
        @output_dir = output_dir
        @requesting_issuer_uuid = requesting_issuer_uuid
      end

      def call
        CSV.open(File.join(output_dir, 'events.csv'), 'w') do |csv|
          csv << %w[
            uuid
            event_name
            date_time
            ip
            disavowed_at
            user_agent
            device_cookie
          ]

          user_report[:user_events].each do |row|
            csv << [requesting_issuer_uuid] + row.values_at(
              :event_name,
              :date_time,
              :ip,
              :disavowed_at,
              :user_agent,
              :device_cookie,
            )
          end
        end
      end
    end
  end
end
