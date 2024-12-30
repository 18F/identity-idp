require 'rails_helper'

RSpec.describe Agreements::IntegrationSeeder do
  describe '.run' do
    let(:seeder) { described_class.new(rails_env: 'production', yaml_path: 'spec/fixtures') }

    before { create(:service_provider, issuer: 'new_issuer') }

    it 'creates new records if none exist' do
      expect { seeder.run }.to change { Agreements::Integration.count }.by(1)
    end
    it 'updates a record if one exists' do
      integration = create(:integration, issuer: 'new_issuer', name: 'Old Name')

      expect { seeder.run }.to \
        change { integration.reload.name }
        .from('Old Name')
        .to('Test Agency App')
    end
  end
end
