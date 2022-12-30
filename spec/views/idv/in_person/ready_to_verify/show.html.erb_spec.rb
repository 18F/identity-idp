require 'rails_helper'

describe 'idv/in_person/ready_to_verify/show.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:user) { build(:user) }
  let(:profile) { build(:profile, user: user) }
  let(:current_address_matches_id) { true }
  let(:selected_location_details) do
    JSON.parse(UspsInPersonProofing::Mock::Fixtures.enrollment_selected_location_details)
  end
  let(:created_at) { Time.zone.parse('2022-07-13') }
  let(:sp_url) { 'http://service.provider.gov' }
  let(:service_provider) { build(:service_provider, return_to_sp_url: sp_url) }
  let(:enrollment) do
    build(
      :in_person_enrollment, :pending,
      current_address_matches_id: current_address_matches_id,
      profile: profile,
      selected_location_details: selected_location_details,
      service_provider: service_provider,
      user: user
    )
  end
  let(:presenter) { Idv::InPerson::ReadyToVerifyPresenter.new(enrollment: enrollment) }
  let(:step_indicator_steps) { Idv::Flows::InPersonFlow::STEP_INDICATOR_STEPS }

  before do
    assign(:presenter, presenter)
    allow(view).to receive(:step_indicator_steps).and_return(step_indicator_steps)
  end

  it 'displays a link back to the service provider' do
    render

    expect(rendered).to have_content(service_provider.friendly_name)
  end

  context 'when the user is not coming from a service provider' do
    let(:service_provider) { nil }

    it 'does not display a link back to a service provider' do
      render

      expect(rendered).not_to have_content('You may now close this window or')
    end
  end

  context 'with enrollment where current address matches id' do
    let(:current_address_matches_id) { true }

    it 'renders without proof of address instructions' do
      render

      expect(rendered).not_to have_content(t('in_person_proofing.process.proof_of_address.heading'))
    end
  end

  context 'with enrollment where current address does not match id' do
    let(:current_address_matches_id) { false }

    it 'renders with proof of address instructions' do
      render

      expect(rendered).to have_content(t('in_person_proofing.process.proof_of_address.heading'))
    end
  end

  context 'with enrollment where selected_location_details is present' do
    it 'renders a location' do
      render

      expect(rendered).to have_content(t('in_person_proofing.body.barcode.retail_hours'))
    end
  end

  context 'with enrollment where selected_location_details is not present' do
    let(:selected_location_details) { nil }

    it 'does not render a location' do
      render

      expect(rendered).not_to have_content(t('in_person_proofing.body.barcode.retail_hours'))
    end
  end
end
