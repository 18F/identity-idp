# frozen_string_literal: true

require 'csv'

module DataRequests
  module Local
    class WriteUserEvents
      attr_reader :user_report, :requesting_issuer_uuid, :csv

      def initialize(user_report:, requesting_issuer_uuid:, csv:, include_header: false)
        @user_report = user_report
        @csv = csv
        @requesting_issuer_uuid = requesting_issuer_uuid
        @include_header = include_header
      end

      def include_header?
        !!@include_header
      end

      def call
        if include_header?
          csv << %w[
            uuid
            event_name
            date_time
            ip
            disavowed_at
            user_agent
            device_cookie
          ]
        end

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
