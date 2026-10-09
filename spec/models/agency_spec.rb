require 'rails_helper'

RSpec.describe Agency do
  describe 'Associations' do
    it { is_expected.to have_many(:agency_identities).dependent(:destroy) }
    it { is_expected.to have_many(:service_providers).inverse_of(:agency) }
    it { is_expected.to have_many(:partner_accounts).class_name('Agreements::PartnerAccount') }
  end
  describe 'validations' do
    let(:agency) { build_stubbed(:agency) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:abbreviation).case_insensitive }
  end

  describe '#delegation_description_for' do
    it 'reads the current locale and falls back to English' do
      agency = create(
        :agency,
        delegation_description: { en: 'helps people find housing.', es: 'ayuda con la vivienda.' },
      )
      expect(agency.delegation_description_for(:es)).to eq('ayuda con la vivienda.')
      expect(agency.delegation_description_for(:fr)).to eq('helps people find housing.')
    end

    it 'is nil when no content has been written' do
      expect(create(:agency).delegation_description_for(:en)).to be_nil
    end
  end
end
