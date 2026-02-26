require 'rails_helper'

RSpec.describe Agreements::PartnerAccountSeeder do
  describe '.run' do
    let(:path) { 'spec/fixtures' }
    let(:seeder) { Agreements::PartnerAccountSeeder.new(rails_env: 'production', yaml_path: path) }

    it 'creates new records if none exist' do
      expect { seeder.run }.to change { Agreements::PartnerAccount.count }.by(1)
    end
    it 'updates a record if one exists' do
      partner_account = create(
        :partner_account,
        requesting_agency: 'DHS-FOO',
        agency: Agency.find_by(abbreviation: 'DHS'),
        partner_account_status: Agreements::PartnerAccountStatus.find_by(name: 'active'),
        crm_id: 123457,
        became_partner: '2018-09-20',
      )

      expect { seeder.run }.to change { partner_account.reload.crm_id }.from(123457).to(123456)
    end

    context 'with bad association' do
      let(:path) { 'spec/fixtures/bad' }

      it 'raises the appropriate error' do
        expect { seeder.run }.to \
          raise_error(ActiveRecord::RecordNotFound, /partner_accounts.yml.+DHS-FOO/)
      end
    end
  end
end
