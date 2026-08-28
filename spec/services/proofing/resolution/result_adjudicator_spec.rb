require 'rails_helper'

RSpec.describe Proofing::Resolution::ResultAdjudicator do
  let(:resolution_success) { true }
  let(:can_pass_with_additional_verification) { false }
  let(:attributes_requiring_additional_verification) { [] }
  let(:resolution_result) do
    Proofing::Resolution::Result.new(
      success: resolution_success,
      errors: {},
      exception: nil,
      vendor_name: 'test-resolution-vendor',
      failed_result_can_pass_with_additional_verification: can_pass_with_additional_verification,
      attributes_requiring_additional_verification: attributes_requiring_additional_verification,
    )
  end
  let(:residential_resolution_result) { resolution_result }

  let(:phone_result) do
    Proofing::AddressResult.new(
      success: true,
      errors: {},
      exception: nil,
      vendor_name: 'test-phone-vendor',
    ).to_h
  end

  let(:ipp_enrollment_in_progress) { false }
  let(:ipp_current_address_matches_id) { false }

  let(:device_profiling_success) { true }
  let(:device_profiling_exception) { nil }
  let(:device_profiling_review_status) { 'pass' }
  let(:device_profiling_result) do
    Proofing::DdpResult.new(
      success: device_profiling_success,
      review_status: device_profiling_review_status,
      client: 'test-device-profiling-vendor',
      exception: device_profiling_exception,
    )
  end
  let(:hybrid_mobile_device_profiling_success) { true }
  let(:hybrid_mobile_device_profiling_exception) { nil }
  let(:hybrid_mobile_device_profiling_review_status) { 'pass' }
  let(:hybrid_mobile_device_profiling_result) do
    Proofing::DdpResult.new(
      success: hybrid_mobile_device_profiling_success,
      review_status: hybrid_mobile_device_profiling_review_status,
      client: 'test-device-profiling-vendor',
      exception: hybrid_mobile_device_profiling_exception,
    )
  end

  let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN }

  let(:proofing_vendor) { :instant_verify_ddp }
  let(:get_to_yes_enabled_vendors) { ['instant_verify', 'instant_verify_ddp'] }

  before do
    allow(IdentityConfig.store).to receive(:idv_aamva_get_to_yes_enabled_vendors)
      .and_return(get_to_yes_enabled_vendors)
  end

  subject do
    described_class.new(
      resolution_result: resolution_result,
      residential_resolution_result: residential_resolution_result,
      ipp_enrollment_in_progress: ipp_enrollment_in_progress,
      device_profiling_result: device_profiling_result,
      hybrid_mobile_device_profiling_result: hybrid_mobile_device_profiling_result,
      phone_result:,
      ipp_current_address_matches_id: ipp_current_address_matches_id,
      applicant_pii: applicant_pii,
      precheck_phone_number: phone_result.empty? ? nil : '202-555-5555',
      proofing_vendor: proofing_vendor,
    )
  end

  describe '#adjudicated_result' do
    context 'IPP enrollment is in progress' do
      let(:ipp_enrollment_in_progress) { true }
      context 'residential address and id address are different' do
        context 'LexisNexis fails for the residential address' do
          let(:resolution_success) { false }
          let(:residential_resolution_result) do
            Proofing::Resolution::Result.new(
              success: resolution_success,
              errors: {},
              exception: nil,
              vendor_name: 'test-resolution-vendor',
              failed_result_can_pass_with_additional_verification:
              can_pass_with_additional_verification,
              attributes_requiring_additional_verification:
              attributes_requiring_additional_verification,
            )
          end
          it 'returns a failed response' do
            result = subject.adjudicated_result

            expect(result.success?).to eq(false)
            resolution_adjudication_reason = result.extra[:context][:resolution_adjudication_reason]
            expect(resolution_adjudication_reason).to eq(:fail_resolution_skip_state_id)
          end
        end
      end
    end

    context 'InstantVerify fails on address verification' do
      let(:resolution_success) { false }
      let(:can_pass_with_additional_verification) { true }
      let(:attributes_requiring_additional_verification) { [:address] }

      context 'AAMVA verified the address' do
        let(:applicant_pii) do
          Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.merge(
            aamva_verified_attributes: [:address],
            address_edited: address_edited,
          )
        end

        context 'the address has not been edited' do
          let(:address_edited) { false }

          it 'lets the verified AAMVA address override the InstantVerify failure' do
            result = subject.adjudicated_result

            expect(result.success?).to eq(true)
            expect(result.extra[:context][:resolution_adjudication_reason])
              .to eq(:state_id_covers_failed_resolution)
          end

          it 'logs the address as a verified attribute' do
            result = subject.adjudicated_result

            expect(result.extra[:biographical_info][:state_id_verified_attributes])
              .to eq([:address])
          end
        end

        context 'the address has been edited' do
          let(:address_edited) { true }

          it 'does not let the verified AAMVA address override the InstantVerify failure' do
            result = subject.adjudicated_result

            expect(result.success?).to eq(false)
            expect(result.extra[:context][:resolution_adjudication_reason])
              .to eq(:fail_resolution_without_state_id_coverage)
          end

          it 'logs the verified attributes without the address' do
            result = subject.adjudicated_result

            expect(result.extra[:biographical_info][:state_id_verified_attributes])
              .to eq([])
          end

          context 'AAMVA verified additional attributes' do
            let(:attributes_requiring_additional_verification) { [:dob] }
            let(:applicant_pii) do
              Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.merge(
                aamva_verified_attributes: [:address, :dob],
                address_edited: address_edited,
              )
            end

            it 'allows those attributes to cover the InstantVerify failure' do
              result = subject.adjudicated_result

              expect(result.success?).to eq(true)
              expect(result.extra[:context][:resolution_adjudication_reason])
                .to eq(:state_id_covers_failed_resolution)
            end

            it 'logs the verified attributes without the address' do
              result = subject.adjudicated_result

              expect(result.extra[:biographical_info][:state_id_verified_attributes])
                .to eq([:dob])
            end
          end
        end
      end

      context 'AAMVA has not verified the address' do
        let(:applicant_pii) do
          Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.merge(
            aamva_verified_attributes: [:dob],
            address_edited: false,
          )
        end

        it 'does not let AAMVA override the InstantVerify failure' do
          result = subject.adjudicated_result

          expect(result.success?).to eq(false)
          expect(result.extra[:context][:resolution_adjudication_reason])
            .to eq(:fail_resolution_without_state_id_coverage)
        end

        it 'logs only the attributes AAMVA verified' do
          result = subject.adjudicated_result

          expect(result.extra[:biographical_info][:state_id_verified_attributes])
            .to eq([:dob])
        end
      end

      context 'get to yes is configured per resolution vendor' do
        let(:applicant_pii) do
          Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.merge(
            aamva_verified_attributes: [:address],
            address_edited: false,
          )
        end

        context 'the resolution vendor that proofed is enabled' do
          [:instant_verify, :instant_verify_ddp].each do |vendor|
            context "when #{vendor} proofed the resolution result" do
              let(:proofing_vendor) { vendor }

              it 'lets AAMVA cover the failure' do
                result = subject.adjudicated_result

                expect(result.success?).to eq(true)
                expect(result.extra[:context][:resolution_adjudication_reason])
                  .to eq(:state_id_covers_failed_resolution)
              end
            end
          end
        end

        context 'no resolution vendor is enabled' do
          let(:get_to_yes_enabled_vendors) { [] }

          it 'does not let AAMVA cover the failure' do
            result = subject.adjudicated_result

            expect(result.success?).to eq(false)
            expect(result.extra[:context][:resolution_adjudication_reason])
              .to eq(:fail_resolution_without_state_id_coverage)
          end
        end

        context 'a different resolution vendor is enabled' do
          let(:proofing_vendor) { :instant_verify_ddp }
          let(:get_to_yes_enabled_vendors) { ['socure_kyc'] }

          it 'does not let AAMVA cover the failure for the vendor that proofed' do
            result = subject.adjudicated_result

            expect(result.success?).to eq(false)
            expect(result.extra[:context][:resolution_adjudication_reason])
              .to eq(:fail_resolution_without_state_id_coverage)
          end
        end

        context 'the proofing vendor is unknown' do
          let(:proofing_vendor) { nil }

          it 'fails closed' do
            result = subject.adjudicated_result

            expect(result.success?).to eq(false)
            expect(result.extra[:context][:resolution_adjudication_reason])
              .to eq(:fail_resolution_without_state_id_coverage)
          end
        end
      end
    end

    describe 'biographical_info' do
      context 'the applicant PII contains one address' do
        it 'includes formatted PII' do
          result = subject.adjudicated_result

          expect(result.extra[:biographical_info]).to eq(
            birth_year: 1938,
            state: 'MT',
            identity_doc_address_state: nil,
            state_id_jurisdiction: 'ND',
            state_id_number: '#############',
            ipp_current_address_matches_id: nil,
            phone: {
              area_code: '202',
              country_code: 'US',
              phone_fingerprint: Pii::Fingerprinter.fingerprint(Phonelib.parse('2025555555').e164),
            },
          )
        end
      end

      context 'the applicant PII contains a residential address and document address' do
        let(:applicant_pii) do
          { aamva_verified_attributes: %i[ssn dob] }.merge(
            Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID,
          )
        end

        it 'includes formatted PII' do
          result = subject.adjudicated_result

          expect(result.extra[:biographical_info]).to eq(
            birth_year: 1938,
            state: 'MT',
            identity_doc_address_state: 'MT',
            state_id_jurisdiction: 'ND',
            state_id_number: '#############',
            state_id_verified_attributes: %i[ssn dob],
            ipp_current_address_matches_id: true,
            phone: {
              area_code: '202',
              country_code: 'US',
              phone_fingerprint: Pii::Fingerprinter.fingerprint(Phonelib.parse('2025555555').e164),
            },
          )
        end
      end
    end
  end
end
