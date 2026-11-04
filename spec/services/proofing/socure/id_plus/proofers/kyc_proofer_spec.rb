require 'rails_helper'

RSpec.describe Proofing::Socure::IdPlus::Proofers::KycProofer do
  let(:analytics) { FakeAnalytics.new }
  let(:is_proofing_agent) { false }
  let(:proofer) { described_class.new(config, analytics, is_proofing_agent:) }
  let(:applicant) { {} }
  let(:api_key) { 'super-$ecret' }
  let(:base_url) { 'https://example.org/' }

  let(:config) do
    Proofing::Socure::IdPlus::Config.new(
      api_key:,
      base_url:,
    )
  end

  let(:result) { proofer.proof(applicant) }

  let(:response_status) { 200 }
  let(:idv_socure_kyc_auto_failure_reason_codes) { ['R995'] }
  let(:get_to_yes_blocking_reason_codes) { [] }
  let(:ssa_proofing_agent_as_authoritative_source) { false }
  let(:ssa_socure_bypass_reason_codes) { [] }

  let(:field_validation_overrides) { {} }
  let(:reason_codes) { %w[I919 I914 I905] }
  let(:web_source) { nil }
  let(:source_attribution) do
    [
      'Credit',
      'Alternative Credit',
      web_source,
    ].compact
  end

  let(:response_body) do
    {
      'referenceId' => 'a-really-unique-id',
      'kyc' => {
        'reasonCodes' => reason_codes,
        'sourceAttribution' => source_attribution,
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
    allow(IdentityConfig.store).to receive(:idv_socure_kyc_auto_failure_reason_codes)
      .and_return(idv_socure_kyc_auto_failure_reason_codes)
    allow(IdentityConfig.store)
      .to receive(:idv_aamva_get_to_yes_socure_kyc_blocking_reason_codes)
      .and_return(get_to_yes_blocking_reason_codes)
    allow(IdentityConfig.store).to receive(:ssa_proofing_agent_as_authoritative_source)
      .and_return(ssa_proofing_agent_as_authoritative_source)
    allow(IdentityConfig.store).to receive(:ssa_socure_bypass_reason_codes)
      .and_return(ssa_socure_bypass_reason_codes)

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

  it 'calls proper analytics event' do
    result
    expect(analytics).to have_logged_event(:idv_socure_kyc_results)
  end

  context 'with source attributions starting with http://' do
    let(:web_source) { 'http://example.org/' }

    it 'obfuscates web-sourced attributions' do
      result
      attribution = analytics.events[:idv_socure_kyc_results][0][:source_attribution]
      expect(attribution).to include 'Web Proof'
    end
  end

  context 'with source attributions starting with https://' do
    let(:web_source) { 'https://example.org/' }

    it 'obfuscates web-sourced attributions' do
      result
      attribution = analytics.events[:idv_socure_kyc_results][0][:source_attribution]
      expect(attribution).to include 'Web Proof'
    end
  end

  it 'reports reason codes as errors' do
    expect(result.reason_codes).to eql(
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

      it 'cannot pass with additional verification' do
        expect(result.failed_result_can_pass_with_additional_verification).to eql(false)
        expect(result.attributes_requiring_additional_verification).to eql([])
      end
    end
  end

  context 'when resolution fails on attributes AAMVA could cover' do
    let(:field_validation_overrides) { { 'streetAddress' => 0.01 } }

    it 'can pass with additional verification' do
      expect(result.success).to eql(false)
      expect(result.failed_result_can_pass_with_additional_verification).to eql(true)
      expect(result.attributes_requiring_additional_verification).to eql([:address])
    end
  end

  context 'when resolution fails on a name' do
    let(:field_validation_overrides) { { 'firstName' => 0.01 } }

    it 'reports the failure as unknown, which blocks a rescue downstream' do
      expect(result.success).to eql(false)
      expect(result.attributes_requiring_additional_verification).to eql([:unknown])
    end
  end

  context 'when an autofail reason code is present alongside a failed attribute' do
    let(:reason_codes) { ['R995'] }
    let(:field_validation_overrides) { { 'streetAddress' => 0.01 } }

    it 'cannot pass with additional verification' do
      expect(result.success).to eql(false)
      expect(result.failed_result_can_pass_with_additional_verification).to eql(false)
    end
  end

  context 'when a rescue blocking reason code is present alongside a failed attribute' do
    let(:get_to_yes_blocking_reason_codes) { ['R909'] }
    let(:reason_codes) { %w[I919 R909] }
    let(:field_validation_overrides) { { 'streetAddress' => 0.01 } }

    it 'reports unknown, which blocks a rescue downstream' do
      expect(result.success).to eql(false)
      expect(result.attributes_requiring_additional_verification).to eql([:address, :unknown])
    end
  end

  context 'when autofail reason code is present' do
    let(:reason_codes) { ['R995'] }

    it 'is not successful' do
      expect(result.success).to eql(false)
    end

    context 'and reason code is not configured as an autofail code' do
      let(:idv_socure_kyc_auto_failure_reason_codes) { ['R111'] }

      it 'is successful' do
        expect(result.success).to eql(true)
      end
    end
  end

  describe 'bypassing reason codes for proofing agents' do
    let(:idv_socure_kyc_auto_failure_reason_codes) { %w[R901 R907 R995] }
    let(:ssa_socure_bypass_reason_codes) { %w[R901 R907] }
    let(:reason_codes) { %w[R901 R907] }

    context 'when the user is not a proofing agent' do
      let(:is_proofing_agent) { false }
      let(:ssa_proofing_agent_as_authoritative_source) { true }

      it 'does not bypass reason codes' do
        expect(result.success).to eql(false)
      end
    end

    context 'when the user is a proofing agent' do
      let(:is_proofing_agent) { true }

      context 'when ssa_proofing_agent_as_authoritative_source is disabled' do
        let(:ssa_proofing_agent_as_authoritative_source) { false }

        it 'does not bypass reason codes' do
          expect(result.success).to eql(false)
        end
      end

      context 'when ssa_proofing_agent_as_authoritative_source is enabled' do
        let(:ssa_proofing_agent_as_authoritative_source) { true }

        context 'when the response is successful' do
          let(:reason_codes) { %w[I919 I914 I905] }

          it 'is successful' do
            expect(result.success).to eql(true)
          end
        end

        context 'when all reason codes on the response are in the bypass list' do
          it 'is successful' do
            expect(result.success).to eql(true)
          end

          it 'still reports the reason codes' do
            expect(result.reason_codes.keys).to match_array(%w[R901 R907])
          end
        end

        context 'when the response reason codes are a subset of the bypass list' do
          let(:reason_codes) { %w[R901] }

          it 'is successful' do
            expect(result.success).to eql(true)
          end
        end

        context 'when the response has reason codes not in the bypass list' do
          let(:reason_codes) { %w[R901 R995] }

          it 'is not successful' do
            expect(result.success).to eql(false)
          end
        end

        context 'when the bypass list is empty' do
          let(:ssa_socure_bypass_reason_codes) { [] }

          it 'is not successful' do
            expect(result.success).to eql(false)
          end
        end
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

  context 'when applicant includes extra fields' do
    let(:applicant) do
      {
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
        expect(result.vendor_name).to eql('socure_kyc')
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
        expect(result.exception).to be_an_instance_of(Proofing::Socure::IdPlus::Request::Error)
      end
    end
  end
end
