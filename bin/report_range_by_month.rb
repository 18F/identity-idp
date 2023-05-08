require 'pathname'
require 'reporting/authentication_report'

# path to your application root.
PATH = Rails.root.join("tmp")

# This is a class to help run cloudwatch queries longer than one month. It
# takes in a start date, end date, issuer, and path
# It is currently designed to be run in the rails console. If you do not pass in
# a path, it create a directory in /tmp based on the year of the last date passed
# in.

# require './bin/report_range_by_month'
# start_date = "2020/10/01"
# end_date = "2021-09-30"
# issuer = "urn:gov:gsa:SAML:2.0.profiles:sp:sso:SSA:mySSAs"
# ReportRangeByMonth.new(start_date:, end_date:, issuer:).run

class ReportRangeByMonth
  def initialize(start_date:, end_date:, issuer:, path: nil)
    @start_date = DateTime.parse(start_date).beginning_of_day
    @end_date = DateTime.parse(end_date).end_of_day
    @issuer = issuer
    @path = path
  end

  def run
    Dir.mkdir dir_path unless Dir.exist? dir_path

    dates.each do |d|
      date = DateTime.parse("#{d[:d]}-#{d[:m]}-#{d[:y]}").in_time_zone('UTC')

      file_path = dir_path.join("#{Date::MONTHNAMES[date.month]}.csv")

      File.write(file_path, authentication_report(date.all_month).to_csv)
      # cmd = "aws-vault exec prod-analytics -- bundle exec rails runner lib/reporting/authentication_report.rb --month" +
      #  " #{date} --issuer #{@issuer} > #{file_path}"
      # puts cmd
      # system cmd
    end
  end

  def authentication_report(date)
    @authentication_report ||= Reporting::AuthenticationReport.new(
      threads: 10,
      slice: 1.hour,
      issuer: @issuer,
      time_range: date
    )
  end

  def dir_path
    @path || PATH.join("FY#{dates.last[:y]}")
  end

  def dates
    (@start_date..@end_date).map {|d| {m: d.month, y: d.year, d: 1 }}.uniq
  end
end
