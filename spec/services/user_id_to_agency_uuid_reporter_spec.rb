require 'rails_helper'

RSpec.describe UserIdToAgencyUuidReporter do
  let(:valid_issuer) { 'valid_issuer' }
  let(:valid_output) { 'tmp/uuids.csv' }

  # DATA
  let!(:agency) { create(:agency) }
  let!(:sp) { create(:service_provider, agency: agency, issuer: 'valid_issuer') }

  describe '.new' do
    it 'raises the appropriate error with invalid issuer' do
      opts = {
        issuer: 'invalid_issuer',
        output: valid_output,
      }

      expect { described_class.new(**opts) }.to \
        raise_error(ArgumentError, /correspond to a service provider/)
    end
    it 'raises the appropriate error when the output file exists' do
      FileUtils.touch(valid_output)

      opts = {
        issuer: valid_issuer,
        output: valid_output,
      }

      expect { described_class.new(**opts) }.to \
        raise_error(ArgumentError, /already exists/)

      File.delete(valid_output)
    end
  end

  describe '.run' do
    context 'with valid inputs' do
      let!(:user1) { create(:user, :signed_up) }
      let!(:user2) { create(:user, :signed_up) }
      let!(:user3) { create(:user, :signed_up) }
      let!(:uuid1) do
        IdentityLinker.new(user1, sp.issuer).link_identity
        AgencyIdentity.find_by(user_id: user1.id, agency_id: agency.id).uuid
      end
      let!(:uuid2) do
        IdentityLinker.new(user2, sp.issuer).link_identity
        AgencyIdentity.find_by(user_id: user2.id, agency_id: agency.id).uuid
      end
      let!(:created_at1) do
        ServiceProviderIdentity.
          find_by(user_id: user1.id, service_provider: valid_issuer).
          created_at
      end
      let!(:created_at2) do
        ServiceProviderIdentity.
          find_by(user_id: user2.id, service_provider: valid_issuer).
          created_at
      end

      let(:opts) do
        {
          issuer: valid_issuer,
          output: valid_output,
        }
      end

      before(:each) do
        IdentityLinker.new(user3, create(:service_provider).issuer).link_identity
      end

      after(:each) { File.delete(valid_output) }

      it 'generates the correct csv' do
        expected = <<~CSV
          old_identifier,new_identifier,created_at
          #{user1.id},#{uuid1},#{created_at1}
          #{user2.id},#{uuid2},#{created_at2}
        CSV

        described_class.run(**opts)

        expect(File.read(valid_output)).to eq(expected)
      end
    end
  end
end
