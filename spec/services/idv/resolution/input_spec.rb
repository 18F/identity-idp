require 'rails_helper'

RSpec.describe Idv::Resolution::Input do
  describe '#from_idv_session' do
    let(:idv_session) do
      {
        pii_from_doc:,
        pii_from_user:,
        ssn:,
      }
    end

    let(:pii_from_doc) { nil }
    let(:pii_from_user) { nil }
    let(:ssn) { nil }

    subject { described_class.from_idv_session(**idv_session) }

    context 'with drivers license' do
      let(:pii_from_doc) { Idp::Constants::MOCK_IDV_APPLICANT }

      it 'maps to state_id' do
        expect(subject.state_id).to eql(
          Idv::Resolution::StateId.new(
            first_name: 'FAKEY',
            middle_name: nil,
            last_name: 'MCFAKERSON',
            dob: '1938-10-06',
            address: Idv::Resolution::Address.new(
              address1: '1 FAKE RD',
              address2: nil,
              city: 'GREAT FALLS',
              state: 'MT',
              zipcode: '59010',
            ),
            number: '1111111111111',
            issuing_jurisdiction: 'ND',
            type: 'drivers_license',
          ),
        )
      end
    end

    context 'with residential address' do
      let(:pii_from_user) { Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID.dup }

      it 'maps to address_of_residence' do
        expect(subject.address_of_residence).to eql(
          Idv::Resolution::Address.new(
            address1: '1 FAKE RD',
            address2: nil,
            city: 'GREAT FALLS',
            state: 'MT',
            zipcode: '59010',
          ),
        )
      end
    end

    context 'with an ssn' do
      let(:ssn) { '666-12-3456' }
      it 'maps to other.ssn' do
        expect(subject.other).to eql(
          Idv::Resolution::OtherAttributes.new(
            ssn:,
          ),
        )
      end
    end
  end

  describe Idv::Resolution::StateId do
    let(:pii_from_doc) do
      Idp::Constants::MOCK_IDV_APPLICANT
    end

    describe '#from_pii_from_doc' do
      it 'works' do
        actual = described_class.from_pii_from_doc(pii_from_doc)
        expect(actual).to eql(
          described_class.new(
            first_name: 'FAKEY',
            middle_name: nil,
            last_name: 'MCFAKERSON',
            dob: '1938-10-06',
            address: Idv::Resolution::Address.new(
              address1: '1 FAKE RD',
              address2: nil,
              city: 'GREAT FALLS',
              state: 'MT',
              zipcode: '59010',
            ),
            number: '1111111111111',
            issuing_jurisdiction: 'ND',
            type: 'drivers_license',
          ),
        )
      end
    end

    describe '#to_pii_from_doc' do
      it 'can convert' do
        actual = described_class.new(
          first_name: 'FAKEY',
          middle_name: nil,
          last_name: 'MCFAKERSON',
          dob: '1938-10-06',
          address: Idv::Resolution::Address.new(
            address1: '1 FAKE RD',
            address2: nil,
            city: 'GREAT FALLS',
            state: 'MT',
            zipcode: '59010',
          ),
          number: '1111111111111',
          issuing_jurisdiction: 'ND',
          type: 'drivers_license',
        ).to_pii_from_doc
        expect(actual).to eql(
          pii_from_doc.slice(
            *%i[
              first_name
              middle_name
              last_name
              dob
              address1
              address2
              city
              state
              zipcode
              state_id_type
              state_id_jurisdiction
              state_id_number
            ],
          ),
        )
      end
    end
  end
end
