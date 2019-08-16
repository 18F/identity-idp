require 'rails_helper'

RSpec.describe UspsConfirmationUploader do
  let(:uploader) { described_class.new }

  let(:export) { 'foo|bar' }
  let(:confirmations) do
    [
      UspsConfirmation.create!(
        entry: {
          first_name: 'John',
          last_name: 'Johnson',
          address1: '123 Sesame St',
          address2: '',
          city: 'Anytown',
          state: 'WA',
          zipcode: '98021',
          otp: 'ZYX987',
          issuer: '',
        },
      ),
    ]
  end

  before do
    allow(Figaro.env).to receive(:usps_upload_enabled).and_return('true')
  end

  describe '#generate_export' do
    subject { uploader.send(:generate_export, confirmations) }

    it 'generates an export using the UspsConfirmationExporter and all current UspsConfirmations' do
      expect(subject).to eq(UspsConfirmationExporter.new(confirmations).run)
    end
  end

  describe '#clear_confirmations' do
    subject { uploader.send(:clear_confirmations, confirmations) }

    it 'deletes the provided confirmations' do
      exist = ->(confirmation) { UspsConfirmation.exists?(confirmation.id) }

      expect(confirmations.all?(&exist)).to eq(true)

      subject

      expect(confirmations.none?(&exist)).to eq(true)
    end
  end

  describe '#upload_export' do
    subject { uploader.send(:upload_export, export) }

    let(:sftp_connection) { instance_double('Net::SFTP::Session') }
    let(:string_io) { StringIO.new(export) }

    it 'uploads the export via sftp' do
      expect(Net::SFTP).to receive(:start).with(*sftp_options).and_yield(sftp_connection)
      expect(StringIO).to receive(:new).with(export).and_return(string_io)
      expect(sftp_connection).to receive(:upload!).with(string_io, upload_folder)

      subject
    end

    it 'does not upload when USPS upload is disabled' do
      allow(Figaro.env).to receive(:usps_upload_enabled).and_return('false')

      expect(Net::SFTP).to_not receive(:start)

      subject
    end
  end

  describe '#run' do
    subject { uploader.run }

    context 'when successful' do
      it 'uploads the psv created by creates a file, uploads it via SFTP, and deletes it after' do
        expect(uploader).to receive(:generate_export).with(confirmations).and_return(export)
        expect(uploader).to receive(:upload_export).with(export)
        expect(uploader).to receive(:clear_confirmations).with(confirmations)

        subject
      end
    end

    context 'when there is an error' do
      it 'notifies NewRelic and does not clear confirmations if SFTP fails' do
        expect(uploader).to receive(:generate_export).with(confirmations).and_return(export)
        expect(uploader).to receive(:upload_export).with(export).and_raise(StandardError)
        expect(uploader).not_to receive(:clear_confirmations)

        expect(NewRelic::Agent).to receive(:notice_error)

        expect { subject }.to_not raise_error

        expect(UspsConfirmation.count).to eq 1
      end
    end
  end

  def sftp_options
    [
      env.usps_upload_sftp_host,
      env.usps_upload_sftp_username,
      password: env.usps_upload_sftp_password,
      timeout: env.usps_upload_sftp_timeout.to_i,
    ]
  end

  def upload_folder
    File.join(Figaro.env.usps_upload_sftp_directory, 'batch.psv')
  end

  def write_permission
    'w'
  end

  def env
    Figaro.env
  end
end
