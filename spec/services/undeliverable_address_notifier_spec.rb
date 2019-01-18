require 'rails_helper'

RSpec.describe UndeliverableAddressNotifier do
  let(:subject) { UndeliverableAddressNotifier.new }
  let(:otp) { 'ABC123' }
  let(:profile) do
    create(
      :profile,
      deactivation_reason: :verification_pending,
      pii: { ssn: '123-45-6789', dob: '1970-01-01' },
    )
  end
  let(:usps_confirmation_code) do
    create(
      :usps_confirmation_code,
      profile: profile,
      otp_fingerprint: Pii::Fingerprinter.fingerprint(otp),
    )
  end
  let(:user) { profile.user }

  it 'processes the file and sends out notifications' do
    mock_data
    notifications_sent = subject.call

    expect(notifications_sent).to eq(1)
    expect(UspsConfirmationCode.first.bounced_at).to be_present
  end

  it 'does not send out notifications to the same user twice after processing twice' do
    mock_data
    notifications_sent = subject.call

    expect(notifications_sent).to eq(1)

    mock_data
    notifications_sent = subject.call

    expect(notifications_sent).to eq(0)
  end

  describe '#download_file' do
    let(:sftp_connection) { instance_double('Net::SFTP::Session') }
    before do
      allow(Net::SFTP).to receive(:start).and_yield(sftp_connection)
      allow(sftp_connection).to receive(:download!)
    end

    it 'downloads the file via sftp' do
      expect(Net::SFTP).to receive(:start).with(*sftp_options).and_yield(sftp_connection)
      expect(sftp_connection).to receive(:download!)

      subject.send(:download_file)
    end
  end

  def create_test_data
    process_file_and_send_notifications
  end

  def mock_data
    usps_confirmation_code
    user
    temp_file = Tempfile.new('foo')
    File.open(temp_file.path, 'w') do |file|
      file.puts otp
    end
    allow_any_instance_of(UndeliverableAddressNotifier).to receive(:download_file).
      and_return(temp_file)
  end

  def download_folder
    File.join(Figaro.env.usps_download_sftp_directory, 'batch.psv')
  end

  def sftp_options
    [
      env.usps_download_sftp_host,
      env.usps_download_sftp_username,
      password: env.usps_download_sftp_password,
      timeout: env.usps_download_sftp_timeout.to_i,
    ]
  end

  def env
    Figaro.env
  end
end
