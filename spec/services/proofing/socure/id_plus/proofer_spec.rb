require 'rails_helper'

RSpec.describe Proofing::Socure::IdPlus::Proofer do
  let(:config) do
  end

  let(:proofer) do
    described_class.new(config)
  end

  let(:applicant) do
    {}
  end

  let(:api_key) { 'super-$ecret' }

  let(:base_url) { 'https://example.org/' }

  let(:config) do
    Proofing::Socure::IdPlus::Config.new(
      api_key:,
      base_url:,
    )
  end

  let(:result) do
    proofer.proof(applicant)
  end

  let(:response_status) { 200 }

  let(:field_validation_overrides) { {} }

  let(:response_body) do
    {
      'referenceId' => 'a-really-unique-id',
      'kyc' => {
        'reasonCodes' => [
          'I919',
          'I914',
          'I905',
        ],
        'fieldValidations' => {
          'firstName' => 0.99,
          'surName' => 0.99,
          'streetAddress' => 0.99,
          'city' => 0.99,
          'state' => 0.99,
          'zip' => 0.99,
          'mobileNumber' => 0.99,
          'dob' => 0.99,
          'ssn' => 0.99,
        }.merge(field_validation_overrides),
      },
    }
  end

  before do
    using_json = !response_body.is_a?(String)

    stub_request(:post, URI.join(base_url, '/api/3.0/EmailAuthScore').to_s).
      to_return(
        status: response_status,
        headers: {
          'Content-Type' => using_json ?
            'application/json' :
            'text/html',
        },
        body: using_json ? JSON.generate(response_body) : response_body,
      )
  end

  it 'reports reason codes as errors' do
    expect(result.errors).to eql(
      {
        'I905' => '[unknown]',
        'I914' => '[unknown]',
        'I919' => '[unknown]',
      },
    )
  end

  context 'when user is 100% matched' do
    it 'returns a resolution result' do
      expect(result).to be_an_instance_of(Proofing::Resolution::Result)
    end

    describe 'the result' do
      it 'is successful' do
        expect(result.success).to eql(true)
      end

      it 'has a vendor name' do
        expect(result.vendor_name).to eql('socure_kyc')
      end

      it 'has a transaction id' do
        expect(result.transaction_id).to eql('a-really-unique-id')
      end

      it('has verified attributes') do
        expect(result.verified_attributes).to eql(
          %i[
            first_name
            last_name
            address
            phone
            dob
            ssn
          ].to_set,
        )
      end
    end
  end

  context 'when parts of address do not match' do
    context '(streetAddress)' do
      let(:field_validation_overrides) { { 'streetAddress' => 0.01 } }
      it 'is not successful' do
        expect(result.success).to eql(false)
      end
      it 'address is not verified' do
        expect(result.verified_attributes).not_to include(:address)
      end
    end
    context '(city)' do
      let(:field_validation_overrides) { { 'city' => 0.01 } }
      it 'is not successful' do
        expect(result.success).to eql(false)
      end
      it 'address is not verified' do
        expect(result.verified_attributes).not_to include(:address)
      end
    end
    context '(state)' do
      let(:field_validation_overrides) { { 'state' => 0.01 } }
      it 'is not successful' do
        expect(result.success).to eql(false)
      end
      it 'address is not verified' do
        expect(result.verified_attributes).not_to include(:address)
      end
    end
    context '(zip)' do
      let(:field_validation_overrides) { { 'zip' => 0.01 } }
      it 'is not successful' do
        expect(result.success).to eql(false)
      end
      it 'address is not verified' do
        expect(result.verified_attributes).not_to include(:address)
      end
    end
  end

  context 'when dob does not match' do
    let(:field_validation_overrides) { { 'dob' => 0.01 } }
    it 'is not successful' do
      expect(result.success).to eql(false)
    end
    it 'address is not verified' do
      expect(result.verified_attributes).not_to include(:dob)
    end
  end

  context 'when ssn does not match' do
    let(:field_validation_overrides) { { 'ssn' => 0.01 } }
    it 'is not successful' do
      expect(result.success).to eql(false)
    end
    it 'address is not verified' do
      expect(result.verified_attributes).not_to include(:ssn)
    end
  end

  context 'when request times out' do
    before do
      stub_request(:post, URI.join(base_url, '/api/3.0/EmailAuthScore').to_s).
        to_timeout
    end

    describe 'the result' do
      it 'is not successful' do
        expect(result.success).to eql(false)
      end

      it 'has a vendor name' do
        expect(result.vendor_name).to eql('socure_kyc')
      end

      it 'does not have transaction id' do
        expect(result.transaction_id).to be_nil
      end

      it 'includes exception details' do
        expect(result.exception).to be_an_instance_of(Proofing::TimeoutError)
      end
    end
  end

  context 'when request returns HTTP 400' do
    let(:response_status) { 400 }
    let(:response_body) do
      {
        status: 'Error',
        referenceId: 'a-big-unique-reference-id',
        data: {
          parameters: ['firstName'],
        },
        msg: 'Request-specific error message goes here',
      }
    end

    describe 'the result' do
      it 'is not successful' do
        expect(result.success).to eql(false)
      end

      it 'has a vendor name' do
        expect(result.vendor_name).to eql('socure_kyc')
      end

      it 'has a transaction id' do
        expect(result.transaction_id).to eql('a-big-unique-reference-id')
      end

      it 'includes exception details' do
        expect(result.exception).to be_an_instance_of(Proofing::Socure::IdPlus::RequestError)
      end
    end
  end

  context 'when request returns HTTP 401' do
    let(:response_status) { 401 }
    let(:response_body) do
      {
        status: 'Error',
        referenceId: 'a-big-unique-reference-id',
        msg: 'Request-specific error message goes here',
      }
    end

    describe 'the result' do
      it 'is not successful' do
        expect(result.success).to eql(false)
      end

      it 'has a vendor name' do
        expect(result.vendor_name).to eql('socure_kyc')
      end

      it 'has a transaction id' do
        expect(result.transaction_id).to eql('a-big-unique-reference-id')
      end

      it 'includes exception details' do
        expect(result.exception).to be_an_instance_of(Proofing::Socure::IdPlus::RequestError)
      end
    end
  end

  context 'when request returns a weird non-JSON HTTP 500' do
    let(:response_status) { 500 }
    let(:response_body) do
      'It works!'
    end

    describe 'the result' do
      it 'is not successful' do
        expect(result.success).to eql(false)
      end

      it 'has a vendor name' do
        expect(result.vendor_name).to eql('socure_kyc')
      end

      it 'does not have a transaction id' do
        expect(result.transaction_id).to be_nil
      end

      it 'includes exception details' do
        expect(result.exception).to be_an_instance_of(Proofing::Socure::IdPlus::RequestError)
      end
    end
  end
end
