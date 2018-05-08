require 'rails_helper'

RSpec.describe UspsUploader do
  subject(:uploader) { UspsUploader.new }

  describe '#run' do
    subject(:run) { uploader.run }

    let(:sftp_connection) { instance_double('Net::SFTP::Session') }

    before do
      sftp_options = [
        Figaro.env.gpo_sftp_host,
        Figaro.env.gpo_sftp_username,
        { key_data: [RequestKeyManager.gpo_ssh_key.to_pem] },
      ]
      expect(Net::SFTP).to receive(:start).
        with(*sftp_options).and_yield(sftp_connection)
    end

    it 'creates a PGP-encrypted file and uploads it via SFTP and deletes it after' do
      expect(sftp_connection).to receive(:upload!).
        with(uploader.local_path.to_s, File.join(Figaro.env.gpo_sftp_directory, 'batch.pgp'))

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
end
