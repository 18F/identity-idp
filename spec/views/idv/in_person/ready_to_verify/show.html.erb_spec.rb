require 'rails_helper'

describe 'idv/in_person/ready_to_verify/show.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:user) { build(:user) }
  let(:profile) { build(:profile, user: user) }
  let(:enrollment_code) { '2048702198804358' }
  let(:current_address_matches_id) { true }
  let(:created_at) { Time.zone.parse('2022-07-13') }
  let(:enrollment) do
    InPersonEnrollment.new(
      user: user,
      profile: profile,
      enrollment_code: enrollment_code,
      created_at: created_at,
    )
  end
  let(:presenter) { Idv::InPerson::ReadyToVerifyPresenter.new(enrollment: enrollment) }

  before do
    assign(:presenter, presenter)
    # WILLFIX: After LG-6708, remove this and initialize enrollment with current_address_matches_id
    allow(presenter).to receive(:needs_proof_of_address?).and_return(!current_address_matches_id)
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
end
