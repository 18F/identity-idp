require 'rails_helper'
require './lib/cleanup/destroyable_records'

RSpec.describe DestroyableRecords do
  let(:stdout) { StringIO.new }
  let(:stdin) { StringIO.new }
  let(:iu) { create(:integration_usage) }
  let(:iaa_order) { iu.iaa_order }
  let(:integration) { iu.integration }
  let(:service_provider) { integration.service_provider }
  let(:in_person_enrollment) {  create(:in_person_enrollment, service_provider:) }

  subject(:destroyable_records) { described_class.new(service_provider.issuer, stdout:, stdin:) }

  describe '#init' do
    it 'instantiates the service_provider' do
      expect(subject.service_provider).to eq service_provider
    end

    it 'instantiates the integration' do
      expect(subject.integration).to eq integration
    end

    it 'instantiates the stdin' do
      expect(subject.stdin).to eq stdin
    end

    it 'instantiates the stdout' do
      expect(subject.stdout).to eq stdout
    end
  end

  describe '#print_data' do
    it 'prints the issuer' do
      issuer = service_provider.issuer
      subject.print_data

      expect(stdout.string).to include(
        "You are about to delete a service provider with issuer #{issuer}",
      )
    end

    it 'prints the partner account name' do
      name = integration.partner_account.name
      subject.print_data

      expect(stdout.string).to include("The partner is #{name}")
    end

    it 'prints the service provider attributes' do
      freeze_time do
        attributes = JSON.parse(service_provider.to_json)
        subject.print_data

        expect(stdout.string).to include attributes.to_yaml
      end
    end

    it 'prints the integration attributes' do
      attributes = integration.attributes.to_yaml
      subject.print_data

      expect(stdout.string).to include attributes
    end

    it 'prints the in-person enrollments size' do
      size = service_provider.in_person_enrollments.size
      msg = "This provider has #{size} in person enrollments " \
        "that will be destroyed"
      subject.print_data

      expect(stdout.string).to include msg
    end

    it 'prints affected iaa orders' do
      subject.print_data

      expect(stdout.string).to include 'These are the IAA orders that will be affected: \n'
      msg = "#{iaa_order.iaa_gtc.gtc_number} Order #{iaa_order.order_number}"
      expect(stdout.string).to include msg
    end
  end

  describe '#destroy_records' do
    let!(:iu2) { create(:integration_usage, iaa_order:) }

    before { subject.destroy_records }

    it 'destroys the integration usages' do
      deleted_iu = Agreements::IntegrationUsage.find_by(id: iu.id)
      expect(deleted_iu).to be nil
    end

    it 'destroys the integration' do
      deleted_int = Agreements::Integration.find_by(id: integration.id)
      expect(deleted_int).to be nil
    end

    it 'destroys the service_provider' do
      deleted_sp = ServiceProvider.find_by(id: service_provider.id)
      expect(deleted_sp).to be nil
    end

    it 'removes the integration from the iaa_order' do
      iaa_order.reload
      expect(iaa_order.integrations.include? integration).to be false
    end

    it 'does not delete unrelated objects' do
      iu2.reload
      iaa_order.reload

      expect(iu2.integration).to be_present
      expect(iu2.integration.service_provider).to be_present
      expect(iaa_order.integrations.include?(iu2.integration)).to be true
    end
  end
end
