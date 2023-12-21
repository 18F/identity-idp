require 'csv'
require 'caxlsx'

class ReportMailer < ActionMailer::Base
  include Mailable

  before_action :attach_images, except: [:tables_report]

  layout 'tables_report', only: [:tables_report]

  def deleted_user_accounts_report(email:, name:, issuers:, data:)
    @name = name
    @issuers = issuers
    @data = data
    attachments['deleted_user_accounts.csv'] = data
    mail(to: email, subject: t('report_mailer.deleted_accounts_report.subject'))
  end

  def system_demand_report(email:, data:, name:)
    @name = name
    attachments['system_demand.csv'] = data
    mail(to: email, subject: t('report_mailer.system_demand_report.subject'))
  end

  def warn_error(email:, error:, env: Rails.env)
    @error = error
    mail(to: email, subject: "[#{env}] identity-idp error: #{error.class.name}")
  end

  # @param [String] email
  # @param [String] subject
  # @param [String] env name of current deploy environment
  # @param [:csv,:xlsx] attachment_format
  # @param [Array<EmailableReport>] reports
  #   an array of tables (which are arrays of rows (arrays of strings))
  #   each table can have a first "row" that is a hash with options
  # @option opts [Boolean] :float_as_percent whether or not to render floats as percents
  # @option opts [Boolean] :title title of the table
  def tables_report(
    email:,
    subject:,
    reports:,
    attachment_format:,
    message: nil,
    env: Identity::Hostdata.env || 'local'
  )
    @message = message

    @reports = reports.map(&:dup).each_with_index do |report, index|
      report.title ||= "Table #{index + 1}"
    end

    case attachment_format
    when :csv
      @reports.each do |report|
        filename = "#{report.filename || report.title.parameterize}.csv"

        attachments[filename] = CSV.generate do |csv|
          report.table.each do |row|
            csv << row
          end
        end
      end
    when :xlsx
      Axlsx::Package.new do |package|
        @reports.each do |report|
          name = report.title.byteslice(0...31)

          package.workbook.add_worksheet(name: name) do |sheet|
            report.table.each do |row|
              sheet.add_row(row)
            end
          end
        end

        attachments['report.xlsx'] = package.to_stream.read
      end
    else
      raise ArgumentError, "unknown attachment_format=#{attachment_format}"
    end

    mail(to: email, subject: "[#{env}] #{subject}")
  end
end
