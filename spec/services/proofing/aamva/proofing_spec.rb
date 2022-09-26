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
  let(:result) { Proofing::Result.new }

  subject do
    described_class.new(
      auth_request_timeout: AamvaFixtures.example_config.auth_request_timeout,
      auth_url: AamvaFixtures.example_config.auth_url,
      cert_enabled: AamvaFixtures.example_config.cert_enabled,
      private_key: AamvaFixtures.example_config.private_key,
      public_key: AamvaFixtures.example_config.public_key,
      verification_request_timeout: AamvaFixtures.example_config.verification_request_timeout,
      verification_url: AamvaFixtures.example_config.verification_url,
    )
  end

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

  describe '#aamva_proof' do
    context 'when verification is successful' do
      it 'the result is successful' do
        subject.aamva_proof(state_id_data, result)

        expect(result.success?).to eq(true)
        expect(result.errors).to be_empty
      end
    end

    context 'when verification is unsuccessful' do
      let(:verification_response) do
        XmlHelper.modify_xml_at_xpath(super(), '//PersonBirthDateMatchIndicator', 'false')
      end

      it 'the result should be failed' do
        subject.aamva_proof(state_id_data, result)

        expect(result.failed?).to eq(true)
        expect(result.errors).to include(dob: ['UNVERIFIED'])
      end
    end

    context 'when verification attributes are missing' do
      let(:verification_response) do
        XmlHelper.delete_xml_at_xpath(super(), '//PersonBirthDateMatchIndicator')
      end

      it 'the result should be failed' do
        subject.aamva_proof(state_id_data, result)

        expect(result.failed?).to eq(true)
        expect(result.errors).to include(dob: ['MISSING'])
      end
    end
  end

  describe '#proof' do
    context 'when verification is successful' do
      let(:applicant_data) do
        {
          uuid: SecureRandom.hex(32),
          dob: '19800101',
          last_name: 'Simpson',
          first_name: 'Homer',
          address1: '123 Street St',
          city: 'Springfield',
          state: 'IL',
          zipcode: '12345',
        }
      end

      let(:aamva_applicant) do
        Aamva::Applicant.from_proofer_applicant(OpenStruct.new(state_id_data.merge(applicant_data)))
      end

      let(:transaction_locator_id) { SecureRandom.uuid }
      let(:verification_response) do
        XmlHelper.modify_xml_at_xpath(super(), '//TransactionLocatorID', transaction_locator_id)
      end

      it 'the result is successful' do
        result = subject.proof(state_id_data.merge(applicant_data))
        expect(result.success?).to eq(true)
        expect(result.errors).to be_empty

        expect(result.transaction_id).to eq(transaction_locator_id)
      end
    end
  end
end
