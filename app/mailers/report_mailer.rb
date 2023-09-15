require 'csv'

class ReportMailer < ActionMailer::Base
  include Mailable

  before_action :attach_images

  def deleted_user_accounts_report(email:, name:, issuers:, data:)
    @name = name
    @issuers = issuers
    @data = data
    attachments['deleted_user_accounts.csv'] = data
    mail(to: email, subject: t('report_mailer.deleted_accounts_report.subject'))
  end

  def sp_issuer_user_counts_report(email:, issuer:, total:, ial1_total:, ial2_total:, name:)
    @name = name
    @issuer = issuer
    @total = total
    @ial1_total = ial1_total
    @ial2_total = ial2_total
    mail(to: email, subject: t('report_mailer.sp_issuer_user_counts_report.subject'))
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
  # @param [Array<Array<Array<String>>>] tables
  #   an array of tables (which are arrays of rows (arrays of strings))
  #   each table can have an first hash with options
  # @option opts [Boolean] :float_as_percent whether or not to render floats as percents
  # @option opts [Boolean] :title title of the table
  def tables_report(email:, subject:, tables:, env: Identity::Hostdata.env)
    @tables = tables.each_with_index.map do |table, index|
      options = table.first.is_a?(Hash) ? table.shift : {}

      options[:title] ||= "Table #{index + 1}"

      [options, *table]
    end

    @tables.each do |options_and_table|
      options, *table = options_and_table

      title = "#{options[:title].parameterize}.csv"

      attachments[title] = CSV.generate do |csv|
        table.each do |row|
          csv << row
        end
      end
    end

    mail(to: email, subject: "[#{env}] #{subject}")
  end
end
