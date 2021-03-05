require 'rails_helper'

RSpec.describe Agreements::PartnerAccountSeeder do
  describe '.run' do
    let(:seeder) { described_class.new(rails_env: 'production', yaml_path: 'spec/fixtures') }

    it 'creates new records if none exits' do
      expect { seeder.run }.to change { Agreements::PartnerAccount.count }.by(1)
    end
    it 'updates a record if one exist' do
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
  end
end
