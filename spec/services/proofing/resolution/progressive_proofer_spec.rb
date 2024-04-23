require 'rails_helper'

RSpec.describe Proofing::Resolution::ProgressiveProofer do
  let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN }
  let(:ipp_enrollment_in_progress) { false }
  let(:threatmetrix_session_id) { SecureRandom.uuid }

  let(:instant_verify_proofing_success) { true }
  let(:instant_verify_proofer_result) do
    instance_double(
      Proofing::Resolution::Result,
      success?: instant_verify_proofing_success,
      attributes_requiring_additional_verification: [:address],
    )
  end
  let(:instant_verify_proofer) do
    instance_double(
      Proofing::LexisNexis::InstantVerify::Proofer,
      proof: instant_verify_proofer_result,
    )
  end

  let(:aamva_proofer_result) { nil }
  let(:aamva_proofer) { instance_double(Proofing::Aamva::Proofer, proof: aamva_proofer_result) }

  let(:threatmetrix_proofer) { instance_double(Proofing::LexisNexis::Ddp::Proofer, proof: nil) }

  let(:proof_id_address_with_lexis_nexis_if_needed_value) { nil }

  let(:dcs_uuid) { SecureRandom.uuid }
  let(:instance) do
    instance = described_class.new(instant_verify_ab_test_discriminator: dcs_uuid)

    allow(instance).to receive(:resolution_proofer).and_call_original
    # allow(instance).to receive(:user_can_pass_after_state_id_check?).and_return(true)
    allow(instance).to receive(:user_can_pass_after_state_id_check?).and_call_original

    instance
  end

  let(:state_id_address) do
    {
      address1: applicant_pii[:identity_doc_address1],
      address2: applicant_pii[:identity_doc_address2],
      city: applicant_pii[:identity_doc_city],
      state: applicant_pii[:identity_doc_address_state],
      state_id_jurisdiction: applicant_pii[:state_id_jurisdiction],
      zipcode: applicant_pii[:identity_doc_zipcode],
    }
  end

  let(:residential_address) do
    {
      address1: applicant_pii[:address1],
      address2: applicant_pii[:address2],
      city: applicant_pii[:city],
      state: applicant_pii[:state],
      state_id_jurisdiction: applicant_pii[:state_id_jurisdiction],
      zipcode: applicant_pii[:zipcode],
    }
  end

  let(:transformed_pii) do
    {
      first_name: 'FAKEY',
      last_name: 'MCFAKERSON',
      dob: '1938-10-06',
      address1: '123 Way St',
      address2: '2nd Address Line',
      city: 'Best City',
      zipcode: '12345',
      state_id_jurisdiction: 'Virginia',
      address_state: 'VA',
      state_id_number: '1111111111111',
      same_address_as_id: 'true',
    }
  end

  let(:ab_test_variables) { {} }

  let(:lniv) do
    instance_double(
      Idv::LexisNexisInstantVerify,
      dcs_uuid,
      workflow_ab_testing_variables: ab_test_variables,
    )
  end

  let(:resolution_result) do
    instance_double(Proofing::Resolution::Result, success?: true, errors: nil)
  end

  def enable_threatmetrix
    allow(FeatureManagement).to receive(:proofing_device_profiling_collecting_enabled?).
      and_return(true)
  end

  def disable_threatmetrix
    allow(FeatureManagement).to receive(:proofing_device_profiling_collecting_enabled?).
      and_return(false)
  end

  def block_real_instant_verify_requests
    allow(Proofing::LexisNexis::InstantVerify::VerificationRequest).to receive(:new)
  end

  before do
    allow(Proofing::LexisNexis::InstantVerify::Proofer).to receive(:new).
      and_return(instant_verify_proofer)
    allow(Idv::LexisNexisInstantVerify).to receive(:new).and_return(lniv)
    allow(Proofing::LexisNexis::Ddp::Proofer).to receive(:new).and_return(threatmetrix_proofer)
    allow(Proofing::Aamva::Proofer).to receive(:new).and_return(aamva_proofer)

    block_real_instant_verify_requests
  end

  describe '#proof' do
    before do
      allow(IdentityConfig.store).to receive(:proofer_mock_fallback).and_return(false)
    end

    subject(:proof) do
      instance.proof(
        applicant_pii: applicant_pii,
        ipp_enrollment_in_progress: ipp_enrollment_in_progress,
        request_ip: Faker::Internet.ip_v4_address,
        should_proof_state_id: true,
        threatmetrix_session_id: threatmetrix_session_id,
        timer: JobHelpers::Timer.new,
        user_email: Faker::Internet.email,
      )
    end

    context 'remote proofing' do
      it 'returns a ResultAdjudicator' do
        expect(proof).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)
        expect(proof.same_address_as_id).to eq(nil)
      end

      context 'ThreatMetrix is enabled' do
        let(:proof_id_address_with_lexis_nexis_if_needed_value) { resolution_result }

        before do
          enable_threatmetrix
          allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_mock_enabled).
            and_return(false)

          proof
        end

        it 'makes a request to the ThreatMetrix proofer' do
          expect(threatmetrix_proofer).to have_received(:proof)
        end

        context 'session id is missing' do
          let(:threatmetrix_session_id) { nil }

          it 'does not make a request to the ThreatMetrix proofer' do
            expect(threatmetrix_proofer).not_to have_received(:proof)
          end

          it 'returns a failed result' do
            device_profiling_result = proof.device_profiling_result

            expect(device_profiling_result.success).to be(false)
            expect(device_profiling_result.client).to eq('tmx_session_id_missing')
            expect(device_profiling_result.review_status).to eq('reject')
          end
        end

        context 'pii is missing' do
          let(:applicant_pii) { {} }

          it 'does not make a request to the ThreatMetrix proofer' do
            expect(threatmetrix_proofer).not_to have_received(:proof)
          end

          it 'returns a failed result' do
            device_profiling_result = proof.device_profiling_result

            expect(device_profiling_result.success).to be(false)
            expect(device_profiling_result.client).to eq('tmx_pii_missing')
            expect(device_profiling_result.review_status).to eq('reject')
          end
        end
      end

      context 'ThreatMetrix is disabled' do
        before do
          disable_threatmetrix
        end

        it 'returns a disabled result' do
          device_profiling_result = proof.device_profiling_result

          expect(device_profiling_result.success).to be(true)
          expect(device_profiling_result.client).to eq('tmx_disabled')
          expect(device_profiling_result.review_status).to eq('pass')
        end
      end

      context 'LexisNexis Instant Verify A/B test enabled' do
        let(:ab_test_variables) do
          {
            ab_testing_enabled: true,
            use_alternate_workflow: true,
            instant_verify_workflow: 'equitable_workflow',
          }
        end

        before { proof }

        it 'uses the selected workflow' do
          expect(Proofing::LexisNexis::InstantVerify::Proofer).to(
            have_received(:new).with(
              hash_including(
                instant_verify_workflow: 'equitable_workflow',
              ),
            ),
          )
        end
      end

      context 'remote flow does not augment pii' do
        before { proof }

        it 'proofs with untransformed pii' do
          expect(aamva_proofer).to have_received(:proof).with(applicant_pii)
          expect(proof.same_address_as_id).to eq(nil)
          expect(proof.ipp_enrollment_in_progress).to eq(false)
          expect(proof.residential_resolution_result.vendor_name).
            to eq('ResidentialAddressNotRequired')
        end
      end
    end

    context 'ipp flow' do
      let(:ipp_enrollment_in_progress) { true }
      let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID }

      it 'returns a ResultAdjudicator' do
        expect(proof).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)
        expect(proof.same_address_as_id).to eq(applicant_pii[:same_address_as_id])
      end

      context 'residential address and id address are the same' do

        it 'only makes one request to LexisNexis InstantVerify' do
          proof

          expect(instant_verify_proofer).to have_received(:proof).exactly(:once)
          expect(aamva_proofer).to have_received(:proof)
        end

        it 'produces a result adjudicator with correct information' do
          expect(proof.same_address_as_id).to eq('true')
          expect(proof.ipp_enrollment_in_progress).to eq(true)
          expect(proof.resolution_result).to eq(proof.residential_resolution_result)
          expect(aamva_proofer).to have_received(:proof)
        end

        it 'uses the transformed PII' do
          allow(instance).to receive(:with_state_id_address).and_return(transformed_pii)

          expect(proof.same_address_as_id).to eq('true')
          expect(proof.ipp_enrollment_in_progress).to eq(true)
          expect(proof.resolution_result).to eq(proof.residential_resolution_result)
          expect(proof.resolution_result.success?).to eq(true)
          expect(aamva_proofer).to have_received(:proof).with(transformed_pii)
        end

        context 'LexisNexis InstantVerify fails' do
          let(:instant_verify_proofing_success) { false }

          it 'includes the state ID in the InstantVerify call' do
            proof

            expect(instance).to have_received(:user_can_pass_after_state_id_check?).
              with(instant_verify_proofer_result)
            expect(instant_verify_proofer).to have_received(:proof).
              with(hash_including(state_id_address))
          end

          context 'the failure can be covered by AAMVA' do
            context 'it is not covered by AAMVA' do
              let(:aamva_proofer_result)  do
                instance_double(
                  Proofing::StateIdResult,
                  verified_attributes: [],
                  success?: false,
                )
              end

              it 'indicates the aamva check did not pass' do
                expect(proof.state_id_result.success?).to eq(false)
              end
            end

            context 'it is covered by AAMVA' do
              let(:aamva_proofer_result) do
                instance_double(
                  Proofing::StateIdResult,
                  verified_attributes: [:address],
                  success?: true,
                )
              end

              it 'indicates aamva did pass' do
                expect(proof.state_id_result.success?).to eq(true)
              end
            end
          end
        end

        context 'LexisNexis InstantVerify passes for residential address and id address' do
          context 'should proof with AAMVA' do
            let(:residential_resolution_that_passed_instant_verify) do
              instance_double(Proofing::Resolution::Result, success?: true)
            end

            before do
              allow(instance).to receive(:proof_residential_address_if_needed).
                and_return(residential_resolution_that_passed_instant_verify)
            end

            it 'makes a request to the AAMVA proofer' do
              proof

              expect(aamva_proofer).to have_received(:proof)
            end

            context 'AAMVA proofing fails' do
              let(:aamva_client) { instance_double(Proofing::Aamva::VerificationClient) }
              let(:aamva_proofer_result) { instance_double(Proofing::StateIdResult, success?: false) }

              before do
                allow(Proofing::Aamva::VerificationClient).to receive(:new).and_return(aamva_client)
              end

              it 'returns a result adjudicator that indicates the aamva proofing failed' do
                expect(proof.state_id_result.success?).to eq(false)
              end
            end
          end
        end
      end

      context 'residential address and id address are different' do
        let(:residential_address_proof) do
          instance_double(Proofing::Resolution::Result)
        end

        let(:ipp_enrollment_in_progress) { true }
        let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS }
        let(:residential_address) do
          {
            address1: applicant_pii[:address1],
            address2: applicant_pii[:address2],
            city: applicant_pii[:city],
            state: applicant_pii[:state],
            state_id_jurisdiction: applicant_pii[:state_id_jurisdiction],
            zipcode: applicant_pii[:zipcode],
          }
        end
        let(:state_id_address) do
          {
            address1: applicant_pii[:identity_doc_address1],
            address2: applicant_pii[:identity_doc_address2],
            city: applicant_pii[:identity_doc_city],
            state: applicant_pii[:identity_doc_address_state],
            state_id_jurisdiction: applicant_pii[:state_id_jurisdiction],
            zipcode: applicant_pii[:identity_doc_zipcode],
          }
        end

        context 'LexisNexis InstantVerify passes for residential address' do
          let(:instant_verify_proofer_result) { residential_address_proof }

          before do
            allow(residential_address_proof).to receive(:success?).and_return(true)
          end

          context 'LexisNexis InstantVerify passes for id address' do
            it 'makes two requests to the InstantVerify Proofer' do
              proof

              expect(instant_verify_proofer).to have_received(:proof).
                with(hash_including(residential_address)).
                ordered
              expect(instant_verify_proofer).to have_received(:proof).
                with(hash_including(state_id_address)).
                ordered
            end

            context 'AAMVA fails' do
              let(:aamva_proofer_result) { instance_double(Proofing::StateIdResult, success?: false) }

              it 'returns the correct resolution results' do
                expect(proof.residential_resolution_result.success?).to be(true)
                expect(proof.resolution_result.success?).to be(true)
                expect(proof.state_id_result.success?).to be(false)
              end
            end
          end
        end

        context 'LexisNexis InstantVerify fails for residential address' do
          let(:instant_verify_proofer_result) { residential_address_proof }

          before do
            allow(instance).to receive(:proof_residential_address_if_needed).
              and_return(residential_address_proof)
            allow(residential_address_proof).to receive(:success?).
              and_return(false)
          end

          it 'does not make unnecessary calls' do
            proof

            expect(aamva_proofer).to_not have_received(:proof)
            expect(instant_verify_proofer).to_not have_received(:proof)
          end
        end

        context 'LexisNexis InstantVerify fails for id address & passes for residential address' do
          let(:result_that_failed_instant_verify) do
            instance_double(Proofing::Resolution::Result)
          end

          before do
            allow(instant_verify_proofer).to receive(:proof).with(hash_including(state_id_address)).
              and_return(result_that_failed_instant_verify)
          end

          context 'the failure can be covered by AAMVA' do
            before do
              allow(instant_verify_proofer).to receive(:proof).and_return(residential_address_proof)
              allow(residential_address_proof).to receive(:success?).and_return(true)

              allow(result_that_failed_instant_verify).
                to receive(:attributes_requiring_additional_verification).
                and_return([:address])

              proof
            end

            it 'calls AAMVA' do
              expect(aamva_proofer).to have_received(:proof)
            end
          end
        end
      end
    end
  end
end
