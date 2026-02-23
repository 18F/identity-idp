require 'rails_helper'

RSpec.describe Agreements::IaaGtcSeeder do
  describe '.run' do
    let(:seeder) do
      Agreements::IaaGtcSeeder.new(rails_env: 'production', yaml_path: 'spec/fixtures')
    end

    it 'creates new records if none exist' do
      expect { seeder.run }.to change { Agreements::IaaGtc.count }.by(1)
    end
    it 'updates a record if one exists' do
      gtc = create(:iaa_gtc, gtc_number: 'LGCBPFY180002', estimated_amount: 100)

      expect { seeder.run }.to change { gtc.reload.estimated_amount }.from(100).to(200)
    end
  end
end
