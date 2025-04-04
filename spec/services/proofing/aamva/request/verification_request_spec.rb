require 'rails_helper'

RSpec.describe Proofing::Aamva::Request::VerificationRequest do
  let(:auth_token) { 'KEYKEYKEY' }
  let(:transaction_id) { '1234-abcd-efgh' }
  let(:config) { AamvaFixtures.example_config }
  let(:state_id_jurisdiction) { 'CA' }
  let(:state_id_number) { '123456789' }
  let(:last_name) { 'McTesterson' }

  let(:applicant_data) do
    {
      uuid: '1234-abcd-efgh',
      first_name: 'Testy',
      middle_name: nil,
      last_name:,
      name_suffix: nil,
      dob: '10/29/1942',
      address1: '123 Sunnyside way',
      address2: nil,
      city: 'Sterling',
      state: 'VA',
      zipcode: '20176-1234',
      eye_color: nil,
      height: nil,
      weight: nil,
      sex: nil,
      state_id_number: state_id_number,
      state_id_jurisdiction: state_id_jurisdiction,
      state_id_type: 'drivers_license',
      state_id_expiration: nil,
      state_id_issued: nil,
    }
  end

  let(:applicant) do
    Proofing::Aamva::Applicant.from_proofer_applicant(**applicant_data.compact_blank)
  end

  subject(:request) do
    described_class.new(
      applicant: applicant,
      session_id: transaction_id,
      auth_token: auth_token,
      config: config,
    )
  end

  describe '#body' do
    it 'should be a request body' do
      expect(subject.body).to match_xml(AamvaFixtures.verification_request)
    end

    it 'should escape XML in applicant data' do
      applicant.first_name = '<foo></bar>'

      expect(subject.body).to_not include('<foo></bar>')
      expect(subject.body).to include('&lt;foo&gt;&lt;/bar&gt;')
    end

    it 'includes an address line 2 if one is present' do
      applicant.address2 = 'Apt 1'

      document = REXML::Document.new(subject.body)
      address_node = REXML::XPath.first(
        document,
        '//dldv:verifyDriverLicenseDataRequest/aa:Address',
      )

      address_node_element_names = address_node.elements.map(&:name)
      address_node_element_values = address_node.elements.map(&:text)

      expect(address_node_element_names).to eq(
        [
          'AddressDeliveryPointText',
          'AddressDeliveryPointText',
          'LocationCityName',
          'LocationStateUsPostalServiceCode',
          'LocationPostalCode',
        ],
      )
      expect(address_node_element_values).to eq(
        [
          applicant.address1,
          applicant.address2,
          applicant.city,
          applicant.state,
          applicant.zipcode,
        ],
      )

      expect(subject.requested_attributes).to include(address2: :present)
    end

    it 'includes issue date if present' do
      applicant.state_id_data.state_id_issued = '2024-05-06'
      expect(subject.body).to include(
        '<aa:DriverLicenseIssueDate>2024-05-06</aa:DriverLicenseIssueDate>',
      )
      expect(subject.requested_attributes).to include(state_id_issued: :present)
    end

    it 'includes expiration date if present' do
      applicant.state_id_data.state_id_expiration = '2030-01-02'
      expect(subject.body).to include(
        '<aa:DriverLicenseExpirationDate>2030-01-02</aa:DriverLicenseExpirationDate>',
      )
      expect(subject.requested_attributes).to include(state_id_expiration: :present)
    end

    it 'includes height if it is present' do
      applicant.height = '63'
      expect(subject.body).to include(
        '<aa:PersonHeightMeasure>63</aa:PersonHeightMeasure>',
      )
      expect(subject.requested_attributes).to include(height: :present)
    end

    it 'includes weight if it is present' do
      applicant.weight = 190
      expect(subject.body).to include(
        '<aa:PersonWeightMeasure>190</aa:PersonWeightMeasure>',
      )
      expect(subject.requested_attributes).to include(weight: :present)
    end

    it 'includes eye_color if it is present' do
      applicant.eye_color = 'blu'
      expect(subject.body).to include(
        '<aa:PersonEyeColorCode>blu</aa:PersonEyeColorCode>',
      )
      expect(subject.requested_attributes).to include(eye_color: :present)
    end

    it 'includes name_suffix if it is present' do
      applicant.name_suffix = 'JR'
      expect(subject.body).to include(
        '<nc:PersonNameSuffixText>JR</nc:PersonNameSuffixText>',
      )
      expect(subject.requested_attributes).to include(name_suffix: :present)
    end

    it 'includes middle_name if it is present' do
      applicant.middle_name = 'test_name'
      expect(subject.body).to include(
        '<nc:PersonMiddleName>test_name</nc:PersonMiddleName>',
      )
      expect(subject.requested_attributes).to include(middle_name: :present)
    end

    context '#sex' do
      context 'when the sex is male' do
        it 'sends a sex code value of 1' do
          applicant.sex = 'male'
          expect(subject.body).to include(
            '<aa:PersonSexCode>1</aa:PersonSexCode>',
          )
          expect(subject.requested_attributes).to include(:sex)
        end
      end

      context 'when the sex is female' do
        it 'sends a sex code value of 2' do
          applicant.sex = 'female'
          expect(subject.body).to include(
            '<aa:PersonSexCode>2</aa:PersonSexCode>',
          )
          expect(subject.requested_attributes).to include(:sex)
        end
      end

      context 'when the sex is blank' do
        it 'does not send a sex code value' do
          applicant.sex = nil
          expect(subject.body).to_not include('<aa:PersonSexCode>')
          expect(subject.requested_attributes).to_not include(:sex)
        end
      end

      context 'when the sex is unsupported' do
        it 'does not send a sex code value' do
          applicant.sex = 'X'
          expect(subject.body).to_not include('<aa:PersonSexCode>')
          expect(subject.requested_attributes).to_not include(:sex)
        end
      end
    end

    context '#state_id_type' do
      context 'when the type is a Drivers License' do
        it 'includes DocumentCategoryCode=1' do
          applicant.state_id_data.state_id_type = 'drivers_license'
          expect(subject.body).to include(
            '<aa:DocumentCategoryCode>1</aa:DocumentCategoryCode>',
          )
          expect(subject.requested_attributes).to include(:state_id_type)
        end
      end

      context 'when the type is a learners permit' do
        it 'includes DocumentCategoryCode=2' do
          applicant.state_id_data.state_id_type = 'drivers_permit'
          expect(subject.body).to include(
            '<aa:DocumentCategoryCode>2</aa:DocumentCategoryCode>',
          )
          expect(subject.requested_attributes).to include(:state_id_type)
        end
      end

      context 'when the type is an ID Card' do
        it 'includes DocumentCategoryCode=3' do
          applicant.state_id_data.state_id_type = 'state_id_card'
          expect(subject.body).to include(
            '<aa:DocumentCategoryCode>3</aa:DocumentCategoryCode>',
          )
          expect(subject.requested_attributes).to include(:state_id_type)
        end
      end

      context 'when the type is something invalid' do
        it 'does not add a DocumentCategoryCode for nil ID type' do
          applicant.state_id_data.state_id_type = nil
          expect(subject.body).to_not include('<aa:DocumentCategoryCode>')
          expect(subject.requested_attributes).to_not include(:state_id_type)
        end

        it 'does not add a DocumentCategoryCode for invalid ID types' do
          applicant.state_id_data.state_id_type = 'License to Keep an Alpaca'
          expect(subject.body).to_not include('<aa:DocumentCategoryCode>')
          expect(subject.requested_attributes).to_not include(:state_id_type)
        end
      end
    end
  end

  describe '#headers' do
    it 'should return valid SOAP headers' do
      expect(subject.headers).to eq(
        'SOAPAction' =>
          '"http://aamva.org/dldv/wsdl/2.1/IDLDVService21/VerifyDriverLicenseData"',
        'Content-Type' => 'application/soap+xml;charset=UTF-8',
        'Content-Length' => subject.body.length.to_s,
      )
    end
  end

  describe '#url' do
    it 'should be the AAMVA verification url from the params' do
      expect(subject.url).to eq(config.verification_url)
    end
  end

  describe '#send' do
    context 'when the request is successful' do
      it 'returns a response object' do
        stub_request(:post, config.verification_url)
          .to_return(body: AamvaFixtures.verification_response, status: 200)

        response = subject.send

        expect(response).to be_an_instance_of(Proofing::Aamva::Response::VerificationResponse)
      end

      it 'sends state id jurisdiction to AAMVA' do
        applicant.state_id_data.state_id_jurisdiction = 'NY'
        expect(
          Nokogiri::XML(subject.body) do |config|
            config.strict
          end.text,
        ).to match(/NY/)
      end
    end

    # rubocop:disable Layout/LineLength
    context 'when the request times out' do
      it 'raises an error' do
        stub_request(:post, config.verification_url)
          .to_timeout

        expect { subject.send }.to raise_error(
          ::Proofing::TimeoutError,
          'AAMVA raised Faraday::ConnectionFailed waiting for verification response: execution expired',
        )
      end
    end
    # rubocop:enable Layout/LineLength

    context 'when the connection fails' do
      it 'raises an error' do
        stub_request(:post, config.verification_url)
          .to_raise(Faraday::ConnectionFailed.new('error'))

        expect { subject.send }.to raise_error(
          ::Proofing::TimeoutError,
          'AAMVA raised Faraday::ConnectionFailed waiting for verification response: error',
        )
      end
    end
  end

  describe '#requested_attributes' do
    let(:applicant_data) do
      {
        first_name: 'Testy',
        last_name: 'McTesterson',
        dob: '10/29/1942',
        address1: '123 Sunnyside way',
        city: 'Sterling',
        state: 'VA',
        zipcode: '20176-1234',
        state_id_number: '98765421',
        state_id_jurisdiction: 'VA',
        state_id_type: 'drivers_license',
      }
    end

    it 'should set present fields to :present' do
      expect(subject.requested_attributes).to match(
        first_name: :present,
        last_name: :present,
        dob: :present,
        address1: :present,
        city: :present,
        state: :present,
        zipcode: :present,
        state_id_number: :present,
        state_id_type: :present,
        state_id_jurisdiction: :present,
      )
    end

    it 'should set required blank fields to :missing' do
      applicant.first_name = nil
      expect(subject.requested_attributes).to include(first_name: :missing)
    end
  end

  describe 'South Carolina id number padding' do
    let(:state_id_jurisdiction) { 'SC' }

    let(:rendered_state_id_number) do
      body = REXML::Document.new(subject.body)
      REXML::XPath.first(body, '//nc:IdentificationID')&.text
    end

    context 'id is greater than 8 digits' do
      it 'passes the id through as is' do
        expect(rendered_state_id_number).to eq(state_id_number)
      end
    end

    context 'id is less than 8 digits' do
      let(:state_id_number) { '1234567' }

      it 'zero-pads the id to 8 digits' do
        expect(rendered_state_id_number).to eq("0#{state_id_number}")
      end
    end
  end

  describe 'compound last names' do
    let(:last_name) { 'McFirst McSecond' }

    subject(:rendered_last_name) do
      body = REXML::Document.new(request.body)
      REXML::XPath.first(body, '//nc:PersonSurName')&.text
    end

    before do
      allow(IdentityConfig.store).to receive(:idv_aamva_split_last_name_states)
        .and_return(['DC'])
    end
    it 'sends the full last name' do
      expect(rendered_last_name).to eq('McFirst McSecond')
    end

    context 'in state configured for last name split' do
      let(:state_id_jurisdiction) { 'DC' }

      it 'only sends the first part of the last name' do
        expect(rendered_last_name).to eq('McFirst')
      end
    end
  end
end
