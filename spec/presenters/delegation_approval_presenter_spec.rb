require 'rails_helper'

RSpec.describe DelegationApprovalPresenter do
  let(:mybenefits) do
    create(:service_provider, :delegation_service_provider, friendly_name: 'MyBenefits Assistant')
  end
  let(:housing) do
    create(
      :service_provider, :delegation_application,
      agency: create(:agency, name: 'Department of Housing Support')
    )
  end
  let(:retirement) do
    create(
      :service_provider, :delegation_application,
      agency: create(:agency, name: 'National Retirement Administration')
    )
  end

  subject(:presenter) do
    described_class.new(service_provider: mybenefits, applications: [retirement, housing])
  end

  it 'groups the selected applications by agency and exposes the service provider card' do
    expect(presenter.sp_name).to eq('MyBenefits Assistant')
    expect(presenter.card.operator_name).to eq('Office of Benefits Coordination')
    expect(presenter.agency_groups.map { |agency, apps| [agency.name, apps] }).to eq(
      [
        ['Department of Housing Support', [housing]],
        ['National Retirement Administration', [retirement]],
      ],
    )
    expect(presenter.remember_months).to eq(12)
  end
end
