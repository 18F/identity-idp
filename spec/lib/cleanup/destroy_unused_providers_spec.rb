require 'rails_helper'
require './lib/cleanup/destroy_unused_providers'

RSpec.describe DestroyUnusedProviders do
  let(:stdout) { StringIO.new }
  let(:stdin) { StringIO.new }
  let(:service_provider) { create(:service_provider) }
  let(:issuer) { service_provider.issuer }

  subject(:destroy_unused_providers) { described_class.new([issuer], stdout:, stdin:) }

  before do
    allow(stdin).to receive(:puts)
  end

  describe '#init' do
    it 'instantiates the stdin' do
      expect(subject.stdin).to eq stdin
    end

    it 'instantiates the stdout' do
      expect(subject.stdout).to eq stdout
    end

    it 'creates the destroy_list' do
      expect(subject.destroy_list.first.class).to eq DestroyableRecords
    end
  end

  describe '#run' do
    describe 'when an issuer does not match an existing service_provider' do
      let(:issuer) { 'issuer-not-in-db' }

      it 'outputs some helpful information' do
        expect(stdout).to receive(:puts).with("Issuer #{issuer} is not associated with a service provider.")
        expect(stdout).to receive(:puts).with('Please check if it has already been deleted')
        subject.run
      end
    end

    describe 'when issuer exists' do
      let(:records) { subject.destroy_list.first }
      let(:response) { 'anything but yes' }
      let(:prompt) do
        "Type 'yes' and hit enter to continue and " \
          "destroy this service provider and associated records:\n"
      end

      before do
        allow(stdin).to receive(:gets) { response }
        allow(records).to receive(:print_data)
      end

      describe 'when user aborts' do
        it 'prints the record data' do
          expect(records).to receive(:print_data)
          subject.run
        end

        it 'asks the user if they want to continue' do
          script_end = 'You have indicated there is an issue. Aborting script'

          expect(stdout).to receive(:puts).with prompt
          expect(stdout).to receive(:puts).with script_end

          subject.run
        end
      end

      describe 'when user continues' do
        let(:response) { 'yes' }
        before do
          allow(stdout).to receive(:puts).with prompt
        end

        it 'calls destroy on the records' do
          expect(records).to receive(:destroy_records)
          subject.run
        end

      end
    end
  end

  # describe 'integration_usages' do
  #   it 'returns the integration usages associated with the integration' do
  #     expect(subject.integration_usages).to eq integration.integration_usages
  #   end
  # end

  # describe 'iaa_orders' do
  #   it 'returns the iaa orders associated with the integration' do
  #     expect(subject.iaa_orders).to eq integration.iaa_orders
  #   end
  # end

  # describe 'destroy_records' do
  #   let!(:iu2) { create(:integration_usage, iaa_order: iaa_order) }

  #   before { subject.destroy_records }

  #   it 'destroys the integration usages' do
  #     deleted_iu = Agreements::IntegrationUsage.find_by(id: iu.id)
  #     expect(deleted_iu).to be nil
  #   end

  #   it 'destroys the integration' do
  #     deleted_int = Agreements::Integration.find_by(id: integration.id)
  #     expect(deleted_int).to be nil
  #   end

  #   it 'destroys the service_provider' do
  #     deleted_sp = ServiceProvider.find_by(id: service_provider.id)
  #     expect(deleted_sp).to be nil
  #   end

  #   it 'removes the integration from the iaa_order' do
  #     iaa_order.reload
  #     expect(iaa_order.integrations.include? integration).to be false
  #   end

  #   it 'does not delete unrelated objects' do
  #     iu2.reload
  #     iaa_order.reload

  #     expect(iu2.integration).to be_present
  #     expect(iu2.integration.service_provider).to be_present
  #     expect(iaa_order.integrations.include?(iu2.integration)).to be true
  #   end
  # end
end
