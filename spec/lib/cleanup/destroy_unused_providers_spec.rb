require 'rails_helper'
require './lib/cleanup/destroy_unused_providers'

RSpec.describe DestroyUnusedProviders do
  let(:stdout) { StringIO.new }
  let(:stdin) { StringIO.new }
  let(:service_provider) { create(:service_provider) }
  let(:issuer) { service_provider.issuer }

  subject(:destroy_unused_providers) { described_class.new([issuer], stdout:, stdin:) }

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
        subject.run

        expect(stdout.string).to include(
          "Issuer #{issuer} is not associated with a service provider.",
        )
        expect(stdout.string).to include('Please check if it has already been deleted')
      end
    end

    describe 'when issuer exists' do
      let(:records) { subject.destroy_list.first }
      let(:stdin) { StringIO.new('anything_but_yes') }
      let(:prompt) do
        "Type 'yes' and hit enter to continue and " \
          "destroy this service provider and associated records:\n"
      end

      before do
        allow(records).to receive(:print_data)
      end

      describe 'when user aborts' do
        it 'prints the record data' do
          expect(records).to receive(:print_data)
          subject.run
        end

        it 'asks the user if they want to continue' do
          script_end = 'You have indicated there is an issue. Aborting script'
          subject.run

          expect(stdout.string).to include prompt
          expect(stdout.string).to include script_end
        end
      end

      describe 'when user continues' do
        let(:stdin) { StringIO.new('yes') }

        it 'calls destroy on the records' do
          expect(records).to receive(:destroy_records)
          subject.run
        end
      end
    end

    describe 'when integration does not exist' do
      let(:records) { subject.destroy_list.first }
      let(:stdin) { StringIO.new('anything_but_yes') }
      let(:partner_account) { integration.partner_account }
      let(:prompt) do
        "Type 'yes' and hit enter to continue and " \
          "destroy this service provider and associated records:\n"
      end

      before do
        allow(records).to receive(:print_data)
      end

      it 'prints the record data' do
        let(:integration) { Agreements::Integration.find_by(issuer: issuer) }
        partner_account.destroy!
        expect(records).to receive(:print_data)
        subject.run
      end
    end
  end
end
