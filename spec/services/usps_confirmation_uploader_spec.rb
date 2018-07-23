require 'rails_helper'

RSpec.describe UspsConfirmationUploader do
  subject(:uploader) { described_class.new }

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

    it 'clears entries after uploading file' do
      expect(UspsConfirmation.count).to eq 1

      subject.run

      expect(UspsConfirmation.count).to eq 0
    end
  end

  def upload_folder
    File.join(Figaro.env.usps_upload_sftp_directory, 'batch.psv')
  end
end


  # let(:otp) { 'ABC123' }
  # let(:pii_attributes) do
  #   Pii::Attributes.new_from_hash(
  #     first_name: 'Söme',
  #     last_name: 'Öne',
  #     address1: '123 Añy St',
  #     address2: 'Sté 123',
  #     city: 'Sömewhere',
  #     state: 'KS',
  #     zipcode: '66666-1234'
  #   )
  # end

  # let(:psv_rows) do
  #   now = Time.zone.now
  #   due = now + described_class::OTP_MAX_VALID_DAYS.days
  #   current_date = now.strftime('%-B %-e')
  #   due_date = due.strftime('%-B %-e')
  #   values = [
  #     described_class::CONTENT_ROW_ID,
  #     pii_attributes.first_name + ' ' + pii_attributes.last_name,
  #     pii_attributes.address1,
  #     pii_attributes.address2,
  #     pii_attributes.city,
  #     pii_attributes.state,
  #     pii_attributes.zipcode,
  #     otp,
  #     "#{current_date}, #{now.year}",
  #     "#{due_date}, #{due.year}",
  #     service_provider.friendly_name,
  #     "https://#{Figaro.env.domain_name}",
  #   ]
  #   values.join(DELIMITER)
  # end


    # before do
    #   confirmation_maker = UspsConfirmationMaker.new(
    #     pii: pii_attributes,
    #     issuer: service_provider.issuer,
    #     profile: build(:profile)
    #   )

    #   allow(confirmation_maker).to receive(:otp).and_return(otp)

    #   confirmation_maker.perform
    # end
