require 'rails_helper'

RSpec.describe Proofing::Socure::IdPlus::Input do
  let(:user) { build(:user) }

  let(:state_id) do
    Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE
  end

  subject do
    described_class.new(
      **state_id.to_h.slice(*described_class.members),
      email: user.first_email,
    )
  end

  it 'creates an appropriate instance' do
    expect(subject.to_h).to eql(
      {
        address1: '1 FAKE RD',
        address2: nil,
        city: 'GREAT FALLS',
        state: 'MT',
        zipcode: '59010-1234',

        first_name: 'FAKEY',
        last_name: 'MCFAKERSON',
        middle_name: nil,

        dob: '1938-10-06',

        phone: '12025551212',
        ssn: '900-66-1234',
        email: user.first_email,
      },
    )
  end
end
