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
      Agreements::Integration.find_by!(issuer:).delete

      expect { seeder.run }.to \
        raise_error(ActiveRecord::RecordNotFound, /iaa_orders.yml.+#{issuer}/)
    end
  end
end
