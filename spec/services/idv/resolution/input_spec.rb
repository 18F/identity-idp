require 'rails_helper'

RSpec.describe Idv::Resolution::Input do
  describe '#from_pii' do
    context 'with idv applicant' do
      subject { described_class.from_pii(pii) }
      let(:pii) { Idp::Constants::MOCK_IDV_APPLICANT }

      it 'maps state_id' do
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

      it 'maps address_of_residence' do
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

      it 'leaves other nil w/o ssn' do
        expect(subject.other).to be_nil
      end
    end

    context 'with ipp applicant who has same address as id' do
      subject { described_class.from_pii(pii) }
      let(:pii) { Idp::Constants::MOCK_IPP_APPLICANT }

      it 'maps state_id correctly' do
        expect(subject.state_id).to eql(
          Idv::Resolution::StateId.new(
            first_name: 'FAKEY',
            middle_name: nil,
            last_name: 'MCFAKERSON',
            dob: '1938-10-06',
            address: Idv::Resolution::Address.new(
              address1: '123 Way St',
              address2: '2nd Address Line',
              city: 'Best City',
              state: 'VA',
              zipcode: '12345',
            ),
            number: '1111111111111',
            issuing_jurisdiction: 'Virginia',
            type: nil,
          ),
        )
      end
      it 'maps address correctly' do
        expect(subject.address_of_residence).to eql(
          Idv::Resolution::Address.new(
            address1: '123 Way St',
            address2: '2nd Address Line',
            city: 'Best City',
            state: 'VA',
            zipcode: '12345',
          ),
        )
      end
    end

    context 'with ipp applicant who has different address on id' do
      subject { described_class.from_pii(pii) }
      let(:pii) { Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS }

      it 'maps identity_doc stuff to state_id' do
        expect(subject.state_id).to eql(
          Idv::Resolution::StateId.new(
            first_name: 'FAKEY',
            middle_name: nil,
            last_name: 'MCFAKERSON',
            dob: '1938-10-06',
            address: Idv::Resolution::Address.new(
              address1: '123 Way St',
              address2: '2nd Address Line',
              city: 'Best City',
              state: 'VA',
              zipcode: '12345',
            ),
            number: '1111111111111',
            issuing_jurisdiction: 'ND',
            type: 'drivers_license',
          ),
        )
      end

      it 'maps address to address_of_residence' do
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
  end

  describe '#initialize' do
    it 'accepts a hash for state_id' do
      actual = described_class.new(
        state_id: {
          first_name: 'FAKEY',
          middle_name: nil,
          last_name: 'MCFAKERSON',
          dob: '1938-10-06',
          address: {
            address1: '1 FAKE RD',
            city: 'GREAT FALLS',
            state: 'MT',
            zipcode: '59010',
          },
          number: '1111111111111',
          issuing_jurisdiction: 'ND',
          type: 'drivers_license',
        },
      )

      expected = described_class.new(
        state_id: Idv::Resolution::StateId.new(
          first_name: 'FAKEY',
          middle_name: nil,
          last_name: 'MCFAKERSON',
          dob: '1938-10-06',
          address: Idv::Resolution::Address.new(
            address1: '1 FAKE RD',
            city: 'GREAT FALLS',
            state: 'MT',
            zipcode: '59010',
          ),
          number: '1111111111111',
          issuing_jurisdiction: 'ND',
          type: 'drivers_license',
        ),
      )

      expect(actual).to eql(expected)
    end

    it 'accepts a hash for address_of_residence' do
      actual = described_class.new(
        address_of_residence: {
          address1: '1234 Fake St.',
          city: 'Faketown',
          state: 'OH',
          zipcode: '34567',
        },
      )

      expected = described_class.new(
        address_of_residence: Idv::Resolution::Address.new(
          address1: '1234 Fake St.',
          city: 'Faketown',
          state: 'OH',
          zipcode: '34567',
        ),
      )

      expect(actual).to eql(expected)
    end

    it 'accepts a hash for other' do
      actual = described_class.new(
        other: {
          ssn: '999-88-7777',
        },
      )
      expected = described_class.new(
        other: Idv::Resolution::OtherAttributes.new(
          ssn: '999-88-7777',
        ),
      )

      expect(actual).to eql(expected)
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

  describe Idv::Resolution::OtherAttributes do
    describe '#initialize' do
      it 'can be called without arguments' do
        other = described_class.new
        expect(other).not_to be_nil
      end

      it 'can be called with all arguments' do
        other = described_class.new(
          ssn: '99-00-1122',
          email: 'test@example.org',
          ip: '10.10.10.10',
          sp_app_id: 'FOO',
          threatmetrix_session_id: 'AF0CD935-992E-482D-80CD-BF2EBD7CCBFF',
        )

        expect(other.to_h).to eql(
          ssn: '99-00-1122',
          email: 'test@example.org',
          ip: '10.10.10.10',
          sp_app_id: 'FOO',
          threatmetrix_session_id: 'AF0CD935-992E-482D-80CD-BF2EBD7CCBFF',
        )
      end
    end
  end
end
