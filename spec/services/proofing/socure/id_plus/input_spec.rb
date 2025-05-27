require 'rails_helper'

RSpec.describe Proofing::Socure::IdPlus::Input do
  let(:user) { build(:user) }

  let(:state_id) do
    Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE.merge(consent_given_at: '2024-09-01T00:00:00Z')
  end

  subject do
    described_class.new(
      **state_id.to_h.slice(*described_class.members),
      email: user.email,
    )
  end

  it 'creates an appropriate instance' do
    expect(subject.to_h).to eql(
      {
        address1: '514 EAST AVE',
        address2: '',
        city: 'SOUTH CHARLESTON',
        state: 'WV',
        zipcode: '25309-1104',

        first_name: 'MICHELE',
        last_name: 'DEBAK',
        middle_name: nil,

        dob: '1976-10-18',

        phone: '12025551212',
        ssn: '900661234',
        email: user.email,

        consent_given_at: '2024-09-01T00:00:00Z',
      },
    )
  end
end
