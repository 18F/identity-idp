require 'rails_helper'

RSpec.describe Agreements::IaaStatusSeeder do
  describe '.run' do
    let(:seeder) { described_class.new(rails_env: 'production', yaml_path: 'spec/fixtures') }

    it 'creates new records if none exist' do
      expect { seeder.run }.to change { Agreements::IaaStatus.count }.by(2)
    end
    it 'updates a record if one exists' do
      status = create(:iaa_status, name: 'test_step_1', order: 124)

      expect { seeder.run }.to change { status.reload.order }.from(124).to(123)
    end
  end
end
