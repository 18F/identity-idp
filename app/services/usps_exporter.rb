class UspsExporter
  OTP_MAX_VALID_DAYS = Figaro.env.usps_confirmation_max_days.to_i
  HEADER_ROW_ID = '01'.freeze
  CONTENT_ROW_ID = '02'.freeze

  def initialize(psv_file_path)
    @psv_file_path = psv_file_path
  end

  def run
    CSV.open(psv_file_path, 'a', col_sep: '|', row_sep: "\r\n") do |csv|
      make_psv(csv)
    end
    clear_confirmations
  end

  private

  attr_reader :psv_file_path

  def make_psv(csv)
    csv << make_header_row(confirmations.size)
    confirmations.each do |confirmation|
      entry = JSON.parse(confirmation.entry, symbolize_names: true)
      csv << make_entry_row(entry)
    end
  end

  def confirmations
    @confirmations ||= UspsConfirmation.all
  end

  def clear_confirmations
    UspsConfirmation.where(id: confirmations.map(&:id)).destroy_all
  end

  def make_header_row(num_entries)
    [HEADER_ROW_ID, num_entries]
  end

  # rubocop:disable MethodLength, AbcSize
  def make_entry_row(entry)
    now = Time.zone.now
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
      "#{now.strftime('%-B %-e')}, #{now.year}",
      "#{due.strftime('%-B %-e')}, #{due.year}",
      service_provider.friendly_name,
      service_provider.return_to_sp_url,
    ]
  end
  # rubocop:enable MethodLength, AbcSize
end
