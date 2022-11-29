require 'csv'

class GpoConfirmationExporter
  DELIMITER = '|'.freeze
  LINE_ENDING = "\r\n".freeze
  HEADER_ROW_ID = '01'.freeze
  CONTENT_ROW_ID = '02'.freeze
  OTP_MAX_VALID_DAYS = IdentityConfig.store.usps_confirmation_max_days

  def initialize(confirmations)
    @confirmations = confirmations
  end

  def run
    CSV.generate(col_sep: DELIMITER, row_sep: LINE_ENDING, &method(:make_psv))
  end

  private

  attr_reader :confirmations

  def make_psv(csv)
    csv << make_header_row(confirmations.size)
    confirmations.each do |confirmation|
      csv << make_entry_row(confirmation)
    end
  end

  def make_header_row(num_entries)
    [HEADER_ROW_ID, num_entries]
  end

  def make_entry_row(confirmation)
    now = current_date
    due = confirmation.created_at + OTP_MAX_VALID_DAYS.days

    entry = confirmation.entry
    service_provider = ServiceProvider.find_by(issuer: entry[:issuer])

    [
      CONTENT_ROW_ID,
      "#{entry[:first_name]} #{entry[:last_name]}",
      entry[:address1],
      entry[:address2],
      entry[:city],
      entry[:state],
      entry[:zipcode],
      entry[:otp],
      format_date(now),
      format_date(due),
      service_provider&.friendly_name || 'Login.gov',
      IdentityConfig.store.domain_name,
    ]
  end

  def format_date(date)
    date.in_time_zone('UTC').strftime('%-B %-e, %Y')
  end

  def current_date
    Time.zone.now
  end
end
