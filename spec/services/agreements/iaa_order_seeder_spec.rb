require 'rails_helper'

RSpec.describe Agreements::IaaOrderSeeder do
  describe '.run' do
    let(:seeder) { described_class.new(rails_env: 'production', yaml_path: 'spec/fixtures') }

    it 'creates new records if none exits' do
      expect { seeder.run }.to change { Agreements::IaaOrder.count }.by(1)
    end
    it 'updates a record if one exist' do
      gtc = Agreements::IaaGtc.find_by!(gtc_number: 'LGCBPFY190002')
      order = create(:iaa_order, iaa_gtc: gtc, order_number: 4, estimated_amount: 100)

    expect { seeder.run }.to change { order.reload.estimated_amount }.from(100).to(200.78)
    end
  end
end
