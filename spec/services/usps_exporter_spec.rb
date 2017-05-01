require 'rails_helper'

describe UspsExporter do
  let(:export_file) { Tempfile.new('usps_export.psv') }
  let(:usps_entry) do
    UspsConfirmationEntry.new_from_hash(
      first_name: 'Some',
      last_name: 'One',
      address1: '123 Any St',
      address2: 'Ste 123',
      city: 'Somewhere',
      state: 'KS',
      zipcode: '66666-1234',
      otp: 123
    )
  end
  let(:psv_row_contents) do
    now = Time.zone.now
    due = now + UspsExporter::OTP_MAX_VALID_DAYS.days
    current_date = now.strftime('%-B %-e')
    due_date = due.strftime('%-B %-e')
    values = [
      UspsExporter::CONTENT_ROW_ID,
      usps_entry.first_name + ' ' + usps_entry.last_name,
      usps_entry.address1,
      usps_entry.address2,
      usps_entry.city,
      usps_entry.state,
      usps_entry.zipcode,
      usps_entry.otp,
      "#{current_date}, #{now.year}",
      "#{due_date}, #{due.year}",
    ]
    values.join('|')
  end

  subject { described_class.new(export_file.path) }

  after do
    export_file.close
    export_file.unlink
  end

  describe '#run' do
    before do
      UspsConfirmation.create(entry: usps_entry.encrypted)
    end

    it 'creates the file' do
      subject.run

      psv_contents = export_file.read

      expect(psv_contents).to eq("01|1\r\n#{psv_row_contents}\r\n")
    end

    it 'clears entries after creating file' do
      expect(UspsConfirmation.count).to eq 1

      subject.run

      expect(UspsConfirmation.count).to eq 0
    end
  end
end
