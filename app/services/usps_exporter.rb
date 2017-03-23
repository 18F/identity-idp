class UspsExporter
  OTP_MAX_VALID_DAYS = 30

  def initialize(csv_file_path)
    @csv_file_path = csv_file_path
  end

  def run
    CSV.open(csv_file_path, 'wb', col_sep: '|') do |csv|
      make_csv(csv)
    end
    clear_entries
  end

  private

  attr_reader :csv_file_path

  def make_csv(csv)
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

  # rubocop:disable MethodLength, AbcSize
  def make_entry_row(entry)
    now = Time.zone.now
    due = now + OTP_MAX_VALID_DAYS.days
    [
      "#{entry.first_name} #{entry.last_name}",
      entry.address1,
      entry.address2,
      entry.city,
      entry.state,
      entry.zipcode,
      entry.otp,
      "#{now.strftime('%B %e')},#{now.year}",
      "#{due.strftime('%B %e')},#{due.year}",
    ]
  end
  # rubocop:enable MethodLength, AbcSize
end
