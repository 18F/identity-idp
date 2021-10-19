require 'rails_helper'

RSpec.describe GpoConfirmationUploader do
  let(:uploader) { described_class.new }

  let(:export) { 'foo|bar' }
  let(:confirmations) do
    [
      GpoConfirmation.create!(
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
    allow(IdentityConfig.store).to receive(:usps_upload_enabled).and_return(true)
  end

  describe '#generate_export' do
    subject { uploader.send(:generate_export, confirmations) }

    it 'generates an export using the GpoConfirmationExporter and all current GpoConfirmations' do
      expect(subject).to eq(GpoConfirmationExporter.new(confirmations).run)
    end
  end

  describe '#clear_confirmations' do
    subject { uploader.send(:clear_confirmations, confirmations) }

    it 'deletes the provided confirmations' do
      exist = ->(confirmation) { GpoConfirmation.exists?(confirmation.id) }

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

    it 'does not upload when GPO upload is disabled' do
      allow(IdentityConfig.store).to receive(:usps_upload_enabled).and_return(false)

      expect(Net::SFTP).to_not receive(:start)

      subject
    end
  end

  describe '#run' do
    subject { uploader.run }

    context 'when successful' do
      it 'uploads the psv, creates a file, uploads it via SFTP, and deletes and logs it after' do
        expect(uploader).to receive(:generate_export).with(confirmations).and_return(export)
        expect(uploader).to receive(:upload_export).with(export)
        expect(uploader).to receive(:clear_confirmations).with(confirmations)

        subject

        logs = LetterRequestsToGpoFtpLog.all
        expect(logs.count).to eq(1)
        log = logs.first
        expect(log.ftp_at).to be_present
        expect(log.letter_requests_count).to eq(1)
      end
    end

    context 'when there is an error' do
      it 'notifies NewRelic and does not clear confirmations if SFTP fails' do
        expect(uploader).to receive(:generate_export).with(confirmations).and_return(export)
        expect(uploader).to receive(:upload_export).with(export).and_raise(StandardError)
        expect(uploader).not_to receive(:clear_confirmations)

        expect(NewRelic::Agent).to receive(:notice_error)

        expect { subject }.to raise_error

        expect(GpoConfirmation.count).to eq 1
      end
    end
  end

  def sftp_options
    [
      IdentityConfig.store.usps_upload_sftp_host,
      IdentityConfig.store.usps_upload_sftp_username,
      password: IdentityConfig.store.usps_upload_sftp_password,
      timeout: IdentityConfig.store.usps_upload_sftp_timeout,
    ]
  end

  def upload_folder
    timestamp = Time.zone.now.strftime('%Y%m%d-%H%M%S')
    File.join(IdentityConfig.store.usps_upload_sftp_directory, "batch#{timestamp}.psv")
  end

  def write_permission
    'w'
  end
end
