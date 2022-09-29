require 'rails_helper'
require 'ostruct'

describe Proofing::Aamva::Proofer do
  let(:aamva_applicant) do
    Aamva::Applicant.from_proofer_applicant(OpenStruct.new(state_id_data))
  end
  let(:state_id_data) do
    {
      state_id_number: '1234567890',
      state_id_jurisdiction: 'VA',
      state_id_type: 'drivers_license',
    }
  end
  let(:verification_results) do
    {
      state_id_number: true,
      dob: true,
      last_name: true,
      last_name_fuzzy: true,
      last_name_fuzzy_alternative: true,
      first_name: true,
      first_name_fuzzy: true,
      first_name_fuzzy_alternative: true,
    }
  end

  subject { described_class.new(AamvaFixtures.example_config.to_h) }

  let(:verification_response) { AamvaFixtures.verification_response }

  before do
    stub_request(:post, AamvaFixtures.example_config.auth_url).
      to_return(
        { body: AamvaFixtures.security_token_response },
        { body: AamvaFixtures.authentication_token_response },
      )
    stub_request(:post, AamvaFixtures.example_config.verification_url).
      to_return(body: verification_response)
  end

  describe '#proof' do
    context 'when verification is successful' do
      it 'the result is successful' do
        result = subject.proof(state_id_data)

        expect(result.success?).to eq(true)
        # TODO: Find a better way to express this than errors
        expect(result.transaction_id).to eq('1234-abcd-efgh')
        expect(result.errors).to eq({})
        expect(result.vendor_name).to eq('aamva:state_id')
        expect(result.exception).to eq(nil)
        expect(result.timed_out?).to eq(false)
      end
    end

    context 'when verification is unsuccessful' do
      let(:verification_response) do
        XmlHelper.modify_xml_at_xpath(
          super(),
          '//PersonBirthDateMatchIndicator',
          'false',
        )
      end

      it 'the result should be failed' do
        result = subject.proof(state_id_data)

        expect(result.success?).to eq(false)
        expect(result.errors).to include(dob: ['UNVERIFIED'])
        expect(result.transaction_id).to eq('1234-abcd-efgh')
        expect(result.vendor_name).to eq('aamva:state_id')
        expect(result.exception).to eq(nil)
        expect(result.timed_out?).to eq(false)
      end
    end

    context 'when verification attributes are missing' do
      let(:verification_response) do
        XmlHelper.delete_xml_at_xpath(
          super(),
          '//PersonBirthDateMatchIndicator',
        )
      end

      it 'the result should be failed' do
        result = subject.proof(state_id_data)

        expect(result.success?).to eq(false)
        expect(result.errors).to include(dob: ['MISSING'])
        expect(result.transaction_id).to eq('1234-abcd-efgh')
        expect(result.vendor_name).to eq('aamva:state_id')
        expect(result.exception).to eq(nil)
        expect(result.timed_out?).to eq(false)
      end
    end
  end
end
