class UspsConfirmationExporter
  DELIMITER = '|'.freeze
  LINE_ENDING = "\r\n".freeze
  HEADER_ROW_ID = '01'.freeze
  CONTENT_ROW_ID = '02'.freeze
  OTP_MAX_VALID_DAYS = Figaro.env.usps_confirmation_max_days.to_i

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
      csv << make_entry_row(confirmation.entry)
    end
  end

  def make_header_row(num_entries)
    [HEADER_ROW_ID, num_entries]
  end

  # rubocop:disable MethodLength, AbcSize
  def make_entry_row(entry)
    now = current_date
    due = now + OTP_MAX_VALID_DAYS.days
    service_provider = ServiceProvider.from_issuer(entry[:issuer])

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
      service_provider.friendly_name || 'Login.gov',
      "https://#{Figaro.env.domain_name}",
    ]
  end
  # rubocop:enable MethodLength, AbcSize

  def format_date(date)
    "#{date.strftime('%-B %-e')}, #{date.year}"
  end

  def current_date
    Time.zone.now
  end
end
