require 'rails_helper'

RSpec.describe UuidReporter do
  let(:valid_email_fixture) { 'spec/fixtures/valid_uuid_report_emails.txt' }
  let(:valid_sp_fixture) { 'spec/fixtures/valid_uuid_report_sps.txt' }
  let(:valid_output) { 'tmp/uuids.csv' }

  # DATA
  let!(:agency) { create(:agency) }
  let!(:sp1) { create(:service_provider, agency_id: agency.id, issuer: 'spissuer1') }
  let!(:sp2) { create(:service_provider, agency_id: agency.id, issuer: 'spissuer2') }

  describe '.new' do
    it 'raises the appropriate error with missing email file' do
      opts = {
        email_file: 'does_not_exist.txt',
        sp_file: valid_sp_fixture,
        output: valid_output,
      }

      expect { described_class.new(**opts) }.to \
        raise_error(ArgumentError, /does not exist/)
    end
    it 'raises the appropriate error when the email file contains an invalid email' do
      opts = {
        email_file: 'spec/fixtures/invalid_uuid_report_emails.txt',
        sp_file: valid_sp_fixture,
        output: valid_output,
      }

      expect { described_class.new(**opts) }.to \
        raise_error(ArgumentError, /must be valid emails/)
    end
    it 'raises the appropriate error with missing sp file' do
      opts = {
        email_file: valid_email_fixture,
        sp_file: 'does_not_exist.txt',
        output: valid_output,
      }

      expect { described_class.new(**opts) }.to \
        raise_error(ArgumentError, /does not exist/)
    end
    it 'raises the appropriate error when the sp file contains an invalid issuer' do
      sp2.delete # it's in the fixture

      opts = {
        email_file: valid_email_fixture,
        sp_file: valid_sp_fixture,
        output: valid_output,
      }

      expect { described_class.new(**opts) }.to \
        raise_error(ArgumentError, /must correspond to a service provider/)
    end
    it 'raises the appropriate error when the sp file contains an SPs from multiple agencies' do
      sp2.update!(agency: create(:agency))

      opts = {
        email_file: valid_email_fixture,
        sp_file: valid_sp_fixture,
        output: valid_output,
      }

      expect { described_class.new(**opts) }.to \
        raise_error(ArgumentError, /must belong to the same agency/)
    end
    it 'raises the appropriate error when the output file exists' do
      FileUtils.touch(valid_output)

      opts = {
        email_file: valid_email_fixture,
        sp_file: valid_sp_fixture,
        output: valid_output,
      }

      expect { described_class.new(**opts) }.to \
        raise_error(ArgumentError, /Output file already exists/)

      File.delete(valid_output)
    end
  end

  describe '.run' do
    context 'with valid inputs' do
      let!(:user1) { create(:user, :fully_registered, email: 'user1@example.com') }
      let!(:user2) { create(:user, :fully_registered, email: 'user2@example.com') }
      let!(:user3) { create(:user, :fully_registered, email: 'user3@example.com') }
      let!(:uuid1) do
        IdentityLinker.new(user1, sp1).link_identity
        AgencyIdentity.find_by(user_id: user1.id, agency_id: agency.id).uuid
      end
      let!(:uuid2) do
        IdentityLinker.new(user2, sp2).link_identity
        AgencyIdentity.find_by(user_id: user2.id, agency_id: agency.id).uuid
      end

      let(:opts) do
        {
          email_file: valid_email_fixture,
          sp_file: valid_sp_fixture,
          output: valid_output,
        }
      end

      before(:each) do
        IdentityLinker.new(user3, create(:service_provider)).link_identity
      end

      after(:each) { File.delete(valid_output) }

      it 'generates the correct csv' do
        expected = <<~CSV
          email_address,uuid
          user1@example.com,#{uuid1}
          user2@example.com,#{uuid2}
          user3@example.com,
          user4@example.com,
        CSV

        described_class.run(**opts)

        expect(File.read(valid_output)).to eq(expected)
      end
    end
  end
end
