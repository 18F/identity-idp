class UspsExporter
  OTP_MAX_VALID_DAYS = Figaro.env.usps_confirmation_max_days.to_i
  HEADER_ROW_ID = '01'.freeze
  CONTENT_ROW_ID = '02'.freeze

  def initialize(psv_file_path)
    @psv_file_path = psv_file_path
  end

  def run
    psv_buffer = CSV.generate(col_sep: '|', row_sep: "\r\n") do |csv|
      make_psv(csv)
    end
    File.open(psv_file_path, 'wb') { |file| file.write psv_buffer }
    clear_entries
  end

  private

  attr_reader :psv_file_path

  def make_psv(csv)
    csv << make_header_row(entries.size)
    entries.map(&:decrypted_entry).each do |entry|
      csv << make_entry_row(entry)
    end
  end

  def entries
    @entries ||= UspsConfirmation.all
  end

  def clear_entries
    UspsConfirmation.where(id: entries.map(&:id)).destroy_all
  end

  def make_header_row(num_entries)
    [HEADER_ROW_ID, num_entries]
  end

  # rubocop:disable MethodLength, AbcSize
  def make_entry_row(entry)
    now = Time.zone.now
    due = now + OTP_MAX_VALID_DAYS.days
    [
      CONTENT_ROW_ID,
      "#{entry.first_name} #{entry.last_name}",
      entry.address1,
      entry.address2,
      entry.city,
      entry.state,
      entry.zipcode,
      entry.otp,
      "#{now.strftime('%-B %-e')}, #{now.year}",
      "#{due.strftime('%-B %-e')}, #{due.year}",
    ]
  end
  # rubocop:enable MethodLength, AbcSize
end
