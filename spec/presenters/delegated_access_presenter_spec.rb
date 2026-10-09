require 'rails_helper'

RSpec.describe DelegatedAccessPresenter do
  let(:user) { create(:user, :fully_registered) }
  let!(:mybenefits) do
    create(:service_provider, :delegation_service_provider, friendly_name: 'MyBenefits Assistant')
  end
  let(:housing_agency) { create(:agency, name: 'Department of Housing Support') }
  let!(:housing) do
    create(
      :service_provider, :delegation_application, agency: housing_agency,
                                                  delegation_scope_value: 'housing_records'
    )
  end
  let!(:retirement) do
    create(
      :service_provider, :delegation_application,
      agency: create(:agency, name: 'National Retirement Administration'),
      delegation_scope_value: 'retirement_benefits'
    )
  end

  subject(:presenter) { described_class.new(user:) }

  before { allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true) }

  it 'lists every approved service provider with every application that accepts it, by agency' do
    expect(presenter.sections.map { |s| s.service_provider }).to eq([mybenefits])
    section = presenter.sections.first
    expect(section.approvable?).to eq(true)
    expect(section.agency_groups.map { |agency, _| agency.name })
      .to eq(['Department of Housing Support', 'National Retirement Administration'])
    expect(section.rows.map(&:application)).to contain_exactly(housing, retirement)
    expect(section.approved_rows).to be_empty
    expect(section.approvable_rows.size).to eq(2)
    expect(presenter.any_approvals?).to eq(false)
  end

  it 'lists a service provider the person has never connected to' do
    expect(user.identities).to be_empty
    expect(presenter.sections.size).to eq(1)
  end

  it 'shows remembered approvals, but not approvals given for a single sign-in' do
    remembered = TokenExchangeGrant.approve!(
      user:, service_provider: mybenefits, application: housing,
      source: 'account_page', remember: true
    )
    TokenExchangeGrant.approve!(
      user:, service_provider: mybenefits, application: retirement,
      source: 'consent_screen', remember: false, rails_session_id: 'abc'
    )

    section = presenter.sections.first
    by_app = section.rows.index_by(&:application)
    expect(by_app[housing].grant).to eq(remembered)
    expect(by_app[retirement].approved?).to eq(false)
    expect(section.approvable_rows.map(&:application)).to eq([retirement])
    expect(presenter.any_approvals?).to eq(true)
  end

  it 'keeps a section for a service provider that lost approval while approvals remain' do
    TokenExchangeGrant.approve!(
      user:, service_provider: mybenefits, application: housing,
      source: 'account_page', remember: true
    )
    mybenefits.update!(token_exchange_enabled_sp: false)

    section = presenter.sections.first
    expect(section.service_provider).to eq(mybenefits)
    expect(section.approvable?).to eq(false)
    expect(section.approved_rows.map(&:application)).to eq([housing])
    expect(section.approvable_rows).to be_empty
  end

  it 'omits an application that stopped accepting the service provider, unless approved' do
    retirement.update!(allowed_delegation_service_providers: ['urn:someone-else'])
    expect(presenter.sections.first.rows.map(&:application)).to eq([housing])
  end

  it 'has no sections when nothing is approved for delegation' do
    mybenefits.update!(token_exchange_enabled_sp: false)
    expect(presenter.sections).to be_empty
  end
end
