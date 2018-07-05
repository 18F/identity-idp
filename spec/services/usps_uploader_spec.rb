require 'rails_helper'

RSpec.describe UspsUploader do
  subject(:uploader) { UspsUploader.new }

  describe '#run' do
    subject(:run) { uploader.run }

    let(:sftp_connection) { instance_double('Net::SFTP::Session') }

    before do
      sftp_options = [
        Figaro.env.usps_upload_sftp_host,
        Figaro.env.usps_upload_sftp_username,
        { password: Figaro.env.usps_upload_sftp_password },
      ]
      expect(Net::SFTP).to receive(:start).
        with(*sftp_options).and_yield(sftp_connection)
    end

    it 'creates a file, uploads it via SFTP, and deletes it after' do
      expect(sftp_connection).to receive(:upload!).
        with(uploader.local_path.to_s, upload_folder)

      run

      expect(File.exist?(uploader.local_path)).to eq(false)
    end

    it 'notifies NewRelic and does not delete the file if SFTP fails' do
      expect(sftp_connection).to receive(:upload!).and_raise(StandardError)
      expect(NewRelic::Agent).to receive(:notice_error)

      expect { run }.to_not raise_error

      expect(File.exist?(uploader.local_path)).to eq(true)
    end
  end

  def upload_folder
    File.join(Figaro.env.usps_upload_sftp_directory, 'batch.psv')
  end
end
