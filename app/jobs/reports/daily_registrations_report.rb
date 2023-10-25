# frozen_string_literal: true

module Reports
  class DailyRegistrationsReport < BaseReport
    REPORT_NAME = 'daily-registrations-report'

    attr_reader :report_date

    include QueryHelpers

    def perform(report_date)
      @report_date = report_date

      _latest, path = generate_s3_paths(REPORT_NAME, 'json', now: report_date)
      body = report_body.to_json

      [
        bucket_name, # default reporting bucket
        IdentityConfig.store.s3_public_reports_enabled && public_bucket_name,
      ].select(&:present?).
        each do |bucket_name|
        upload_file_to_s3_bucket(
          path: path,
          body: body,
          content_type: 'application/json',
          bucket: bucket_name,
        )
      end
    end

    def finish
      report_date.end_of_day
    end

    def report_body
      results = [*total_users, *fully_registered_users, *deleted_users].
        group_by { |row| row['date'] }.
        map do |date, rows|
          {
            date: date,
            total_users: rows.map { |r| r['total_users'] }.compact.first || 0,
            fully_registered_users: rows.map { |r| r['fully_registered_users'] }.compact.first || 0,
            deleted_users: rows.map { |r| r['deleted_users'] }.compact.first || 0,
          }
        end.sort_by { |elem| elem[:date] }

      {
        finish: finish,
        results: results.as_json,
      }
    end

    # Queries for all the users that were ever created by date
    # (includes users who were later deleted)
    def total_users
      params = {
        finish: finish,
      }.transform_values { |v| quote(v) }

      sql = format(<<-SQL, params)
        SELECT
          COUNT(*) AS total_users
        , user_and_deleted_users.date AS date
        FROM
        (
          SELECT created_at::date AS date
          FROM users
          WHERE users.created_at <= %{finish}

          UNION ALL

          SELECT deleted_users.user_created_at::date AS date
          FROM deleted_users
          WHERE
              deleted_users.deleted_at <= %{finish}
          AND deleted_users.user_created_at <= %{finish}
        ) user_and_deleted_users
        GROUP BY user_and_deleted_users.date
      SQL

      transaction_with_timeout do
        ActiveRecord::Base.connection.execute(sql)
      end
    end

    def fully_registered_users
      params = {
        finish: finish,
      }.transform_values { |v| quote(v) }

      sql = format(<<-SQL, params)
        SELECT
          COUNT(*) AS fully_registered_users
        , registered_at::date AS date
        FROM registration_logs
        WHERE
          registered_at <= %{finish}
        GROUP BY
          registered_at::date
      SQL

      transaction_with_timeout do
        ActiveRecord::Base.connection.execute(sql)
      end
    end

    # Queries for users who where deleted, groups by the date they were deleted at
    def deleted_users
      params = {
        finish: finish,
      }.transform_values { |v| quote(v) }

      sql = format(<<-SQL, params)
        SELECT
          COUNT(*) AS deleted_users
        , deleted_at::date AS date
        FROM deleted_users
        WHERE
            deleted_at <= %{finish}
        AND deleted_users.user_created_at <= %{finish}
        GROUP BY
          deleted_at::date
      SQL

      transaction_with_timeout do
        ActiveRecord::Base.connection.execute(sql)
      end
    end
  end
end
