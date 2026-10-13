require 'rails_helper'

RSpec.describe DelegationApplications do
  let(:service_provider_issuer) { 'urn:gov:gsa:openidconnect:sp:mybenefits' }
  let(:housing) { create(:agency, name: 'Department of Housing Support') }
  let(:retirement) { create(:agency, name: 'National Retirement Administration') }

  let!(:open_application) do
    create(
      :service_provider, :delegation_application,
      agency: housing, friendly_name: 'Housing Assistance Records'
    )
  end
  let!(:listed_application) do
    create(
      :service_provider, :delegation_application,
      agency: retirement, friendly_name: 'Retirement Benefits Portal',
      allowed_delegation_service_providers: [service_provider_issuer]
    )
  end
  let!(:other_providers_only) do
    create(
      :service_provider, :delegation_application,
      agency: retirement, friendly_name: 'Mailing Address Service',
      allowed_delegation_service_providers: ['urn:gov:gsa:openidconnect:sp:someone-else']
    )
  end
  let!(:not_an_application) do
    create(:service_provider, :active, agency: housing, friendly_name: 'Ordinary sign-in app')
  end

  describe '.accepting' do
    it 'returns active applications with an empty list or one naming the service provider' do
      expect(described_class.accepting(service_provider_issuer))
        .to contain_exactly(open_application, listed_application)
    end

    it 'excludes inactive applications' do
      open_application.update!(active: false)
      expect(described_class.accepting(service_provider_issuer)).to eq([listed_application])
    end

    it 'returns nothing for a blank issuer' do
      expect(described_class.accepting(nil)).to eq([])
    end

    it 'sorts by display name' do
      names = described_class.accepting(service_provider_issuer).map(&:display_name)
      expect(names).to eq(names.sort_by(&:downcase))
    end
  end

  describe '.grouped_by_agency' do
    it 'groups applications under their agency, agencies and applications sorted by name' do
      grouped = described_class.grouped_by_agency(
        [listed_application, open_application, other_providers_only],
      )

      expect(grouped.map { |agency, _| agency.name })
        .to eq(['Department of Housing Support', 'National Retirement Administration'])
      expect(grouped.last.last.map(&:display_name))
        .to eq(['Mailing Address Service', 'Retirement Benefits Portal'])
    end
  end
end
