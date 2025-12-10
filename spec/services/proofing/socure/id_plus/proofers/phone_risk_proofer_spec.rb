# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Proofing::Socure::IdPlus::Proofers::PhoneRiskProofer do
  let(:api_key) { 'super-$ecret' }
  let(:base_url) { 'https://example.org/' }
  let(:user_uuid) { 'test-user-uuid' }

  let(:config) do
    Proofing::Socure::IdPlus::Config.new(
      api_key:,
      base_url:,
      user_uuid:,
    )
  end

  let(:proofer) do
    described_class.new(config)
  end

  let(:applicant) do
    {
      phone: '+1 555-123-4567',
      first_name: 'John',
      last_name: 'Doe',
      address1: '123 Main St',
      address2: 'Apt 4',
      city: 'New York',
      state: 'NY',
      zipcode: '10001',
      email: 'john.doe@example.com',
    }
  end

  let(:result) do
    proofer.proof(applicant)
  end

  let(:response_status) { 200 }
  let(:phonerisk_low) { true }
  let(:name_phone_correlation_high) { true }
  let(:name_phone_reason_codes) { ['I123', 'R567', 'R890'] }
  let(:phonerisk_reason_codes) { ['I919', 'I914'] }

  let(:response_body) do
    {
      'referenceId' => 'a-really-unique-id',
      'namePhoneCorrelation' => {
        'reasonCodes' => name_phone_reason_codes,
        'score' => name_phone_correlation_high ? 0.99 : 0.01,
      },
      'phoneRisk' => {
        'reasonCodes' => phonerisk_reason_codes,
        'score' => phonerisk_low ? 0.01 : 0.99,
      },
      'customerProfile' => {
        'customerUserId' => user_uuid,
      },
    }
  end

  before do
    using_json = !response_body.is_a?(String)

    stub_request(:post, URI.join(base_url, '/api/3.0/EmailAuthScore').to_s)
      .to_return(
        status: response_status,
        headers: {
          'Content-Type' => using_json ?
            'application/json' :
            'text/html',
        },
        body: using_json ? JSON.generate(response_body) : response_body,
      )
  end

  context 'when phone risk check is successful' do
    it 'returns an AddressResult' do
      expect(result).to be_an_instance_of(Proofing::AddressResult)
    end

    describe 'the result' do
      it 'is successful' do
        expect(result.success).to eql(true)
      end

      it 'has a vendor name' do
        expect(result.vendor_name).to eql('socure_phonerisk')
      end

      it 'has a transaction id' do
        expect(result.transaction_id).to eql('a-really-unique-id')
      end

      it 'has a reference' do
        expect(result.reference).to eql('a-really-unique-id')
      end

      it 'has no errors' do
        expect(result.errors).to eql({})
      end

      it 'has no exception' do
        expect(result.exception).to be_nil
      end

      it 'includes the response data in result' do
        expect(result.result).to be_a(Hash)
        expect(result.result).to have_key(:phonerisk)
        expect(result.result).to have_key(:name_phone_correlation)
      end
    end
  end

  context 'when phonerisk score is above threshold' do
    let(:phonerisk_low) { false }
    let(:name_phone_reason_codes) { [] }

    it 'is not successful' do
      expect(result.success).to eql(false)
    end

    it 'includes reason codes in errors' do
      expect(result.errors).to have_key(:socure)
      expect(result.errors[:socure]).to have_key(:reason_codes)

      reason_codes = result.errors[:socure][:reason_codes]
      expect(reason_codes).to eql(
        {
          'I919' => '[unknown]',
          'I914' => '[unknown]',
        },
      )
    end
  end

  context 'when name phone correlation score is below threshold' do
    let(:name_phone_correlation_high) { false }
    let(:phonerisk_reason_codes) { [] }

    it 'is not successful' do
      expect(result.success).to eql(false)
    end

    it 'includes reason codes in errors' do
      expect(result.errors).to have_key(:socure)
      expect(result.errors[:socure]).to have_key(:reason_codes)

      reason_codes = result.errors[:socure][:reason_codes]
      expect(reason_codes).to eql(
        {
          'I123' => '[unknown]',
          'R567' => '[unknown]',
          'R890' => '[unknown]',
        },
      )
    end
  end

  context 'when both checks fail' do
    let(:phonerisk_low) { false }
    let(:name_phone_correlation_high) { false }

    it 'is not successful' do
      expect(result.success).to eql(false)
    end

    it 'includes combined reason codes from both sections' do
      expect(result.errors).to have_key(:socure)
      expect(result.errors[:socure]).to have_key(:reason_codes)

      reason_codes = result.errors[:socure][:reason_codes]
      expect(reason_codes).to eql(
        {
          'I919' => '[unknown]',
          'I914' => '[unknown]',
          'I123' => '[unknown]',
          'R567' => '[unknown]',
          'R890' => '[unknown]',
        },
      )
    end

    it 'uses unknown for undefined reason codes' do
      reason_codes = result.errors[:socure][:reason_codes]
      reason_codes.each_value do |definition|
        expect(definition).to eq('[unknown]')
      end
    end
  end

  context 'when applicant includes extra fields' do
    let(:applicant) do
      {
        phone: '+1 555-123-4567',
        some_weird_field_the_proofer_is_not_expecting: ':ohno:',
      }
    end

    it 'does not raise an error' do
      expect { result }.not_to raise_error
    end
  end

  context 'when request times out' do
    before do
      stub_request(:post, URI.join(base_url, '/api/3.0/EmailAuthScore').to_s)
        .to_timeout
    end

    describe 'the result' do
      it 'is not successful' do
        expect(result.success).to eql(false)
      end

      it 'has a vendor name' do
        expect(result.vendor_name).to eql('socure_phonerisk')
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
          parameters: ['mobileNumber'],
        },
        msg: 'Request-specific error message goes here',
      }
    end

    describe 'the result' do
      it 'is not successful' do
        expect(result.success).to eql(false)
      end

      it 'has a vendor name' do
        expect(result.vendor_name).to eql('socure_phonerisk')
      end

      it 'has a transaction id' do
        expect(result.transaction_id).to eql('a-big-unique-reference-id')
      end

      it 'includes exception details' do
        expect(result.exception).to be_an_instance_of(Proofing::Socure::IdPlus::Request::Error)
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
        expect(result.vendor_name).to eql('socure_phonerisk')
      end

      it 'has a transaction id' do
        expect(result.transaction_id).to eql('a-big-unique-reference-id')
      end

      it 'includes exception details' do
        expect(result.exception).to be_an_instance_of(Proofing::Socure::IdPlus::Request::Error)
      end
    end
  end

  context 'when request returns a weird non-JSON HTTP 500' do
    let(:response_status) { 500 }
    let(:response_body) do
      'Internal Server Error'
    end

    describe 'the result' do
      it 'is not successful' do
        expect(result.success).to eql(false)
      end

      it 'has a vendor name' do
        expect(result.vendor_name).to eql('socure_phonerisk')
      end

      it 'does not have a transaction id' do
        expect(result.transaction_id).to be_nil
      end

      it 'includes exception details' do
        expect(result.exception).to be_an_instance_of(Proofing::Socure::IdPlus::Request::Error)
      end
    end
  end
end
