require 'rails_helper'
require './lib/destroy_unused_providers'

RSpec.describe DestroyUnusedProviders::DestroyableRecords do
  let(:iu) { create(:integration_usage) }
  let(:iaa_order) { iu.iaa_order }
  let(:integration) { iu.integration }
  let(:service_provider) { integration.service_provider }
  let(:in_person_enrollment) {  create(:in_person_enrollment, service_provider: service_provider) }

  subject(:destroyable_records) { described_class.new(service_provider.issuer) }

  describe '#init' do
    it 'attaches the service_provider' do
      expect(subject.sp).to eq service_provider
    end

    it 'attaches the integration' do
      expect(subject.int).to eq integration
    end
  end

  describe 'integration_usages' do
    it 'returns the integration usages associated with the integration' do
      expect(subject.integration_usages).to eq integration.integration_usages
    end
  end

  describe 'iaa_orders' do
    it 'returns the iaa orders associated with the integration' do
      expect(subject.iaa_orders).to eq integration.iaa_orders
    end
  end

  describe 'destroy_records' do
    let!(:iu2) { create(:integration_usage, iaa_order: iaa_order) }

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
