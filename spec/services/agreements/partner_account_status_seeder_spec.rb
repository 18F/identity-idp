require 'rails_helper'

RSpec.describe Agreements::PartnerAccountStatusSeeder do
  describe '.run' do
    let(:path) { 'spec/fixtures' }
    let(:seeder) { described_class.new(rails_env: 'production', yaml_path: path) }

    it 'creates new records if none exist' do
      expect { seeder.run }.to change { Agreements::PartnerAccountStatus.count }.by(2)
    end
    it 'updates a record if one exists' do
      status = create(:partner_account_status, name: 'test_step_1', order: 124)

      expect { seeder.run }.to change { status.reload.order }.from(124).to(123)
    end

    context 'with bad file' do
      let(:path) { 'spec/fixtures/bad' }

      it 'raises the appropriate error' do
        expect { seeder.run }.to \
          raise_error(ActiveRecord::RecordInvalid, /partner_account_statuses.yml.+test_step_1/)
      end
    end
  end
end
