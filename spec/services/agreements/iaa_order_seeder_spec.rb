require 'rails_helper'

RSpec.describe Agreements::IaaOrderSeeder do
  describe '.run' do
    let(:seeder) { described_class.new(rails_env: 'production', yaml_path: 'spec/fixtures') }

    it 'creates new IaaOrders if none exist' do
      expect { seeder.run }.to change { Agreements::IaaOrder.count }.by(1)
    end
    it 'creates new IntegrationUsages if none exist' do
      expect { seeder.run }.to change { Agreements::IntegrationUsage.count }.by(1)
    end
    it 'updates a record if one exists' do
      gtc = Agreements::IaaGtc.find_by!(gtc_number: 'LGCBPFY190002')
      order = create(:iaa_order, iaa_gtc: gtc, order_number: 4, estimated_amount: 100)

      expect { seeder.run }.to change { order.reload.estimated_amount }.from(100).to(200.78)
    end
    it 'raises the appropriate error message if the integration issuer is invalid' do
      issuer = 'https://rp1.serviceprovider.com/auth/saml/metadata'
      Agreements::IntegrationUsage.delete_all
      Agreements::Integration.find_by!(issuer: issuer).delete

      expect { seeder.run }.to \
        raise_error(ActiveRecord::RecordNotFound, /iaa_orders.yml.+#{issuer}/)
    end

    it 'removes IntegrationUsage records that are no longer in the YAML file' do
      gtc = Agreements::IaaGtc.find_by!(gtc_number: 'LGCBPFY190002')
      order = create(:iaa_order, iaa_gtc: gtc, order_number: 4)

      integration = Agreements::Integration.find_by!(issuer: 'https://rp1.serviceprovider.com/auth/saml/metadata')
      usage = create(:integration_usage, iaa_order: order, integration: integration)

      old_integration = create(:integration, issuer: 'https://other.example.com/metadata')
      old_usage = create(:integration_usage, iaa_order: order, integration: old_integration)

      expect(Rails.logger).to receive(:info).with(/Removing 1 orphaned IntegrationUsage records/)
      expect { seeder.run }.to change { Agreements::IntegrationUsage.count }.by(-1)

      expect(Agreements::IntegrationUsage.exists?(usage.id)).to be true
      expect(Agreements::IntegrationUsage.exists?(old_usage.id)).to be false
    end
  end
end
