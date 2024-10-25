require 'rails_helper'

RSpec.describe Proofing::Resolution::ProgressiveProofer do
  let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN }
  let(:ipp_enrollment_in_progress) { false }
  let(:threatmetrix_session_id) { SecureRandom.uuid }
  let(:current_sp) { build(:service_provider) }

  let(:instant_verify_proofing_success) { true }
  let(:instant_verify_proofer_result) do
    instance_double(
      Proofing::Resolution::Result,
      success?: instant_verify_proofing_success,
      attributes_requiring_additional_verification: [:address],
      transaction_id: 'ln-123',
    )
  end
  let(:instant_verify_proofer) do
    instance_double(
      Proofing::LexisNexis::InstantVerify::Proofer,
      proof: instant_verify_proofer_result,
    )
  end

  let(:aamva_proofer_result) do
    instance_double(
      Proofing::StateIdResult,
      success?: false,
      transaction_id: 'aamva-123',
      exception: nil,
    )
  end
  let(:aamva_proofer) { instance_double(Proofing::Aamva::Proofer, proof: aamva_proofer_result) }

  let(:threatmetrix_proofer_result) do
    instance_double(Proofing::DdpResult, success?: true, transaction_id: 'ddp-123')
  end
  let(:threatmetrix_proofer) do
    instance_double(
      Proofing::LexisNexis::Ddp::Proofer,
      proof: threatmetrix_proofer_result,
    )
  end

  let(:dcs_uuid) { SecureRandom.uuid }

  subject(:progressive_proofer) { described_class.new }

  let(:state_id_address) do
    {
      address1: applicant_pii[:identity_doc_address1],
      address2: applicant_pii[:identity_doc_address2],
      city: applicant_pii[:identity_doc_city],
      state: applicant_pii[:identity_doc_address_state],
      zipcode: applicant_pii[:identity_doc_zipcode],
    }
  end

  let(:residential_address) do
    {
      address1: applicant_pii[:address1],
      address2: applicant_pii[:address2],
      city: applicant_pii[:city],
      state: applicant_pii[:state],
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
      state_id_jurisdiction: 'VA',
      address_state: 'VA',
      state_id_number: '1111111111111',
      same_address_as_id: 'true',
    }
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
    allow(progressive_proofer).to receive(:resolution_proofer).and_return(instant_verify_proofer)
    allow(progressive_proofer).to receive(:lexisnexis_ddp_proofer).and_return(threatmetrix_proofer)
    allow(progressive_proofer).to receive(:state_id_proofer).and_return(aamva_proofer)

    block_real_instant_verify_requests
  end

  describe '#proof' do
    before do
      allow(IdentityConfig.store).to receive(:proofer_mock_fallback).and_return(false)
    end

    subject(:proof) do
      progressive_proofer.proof(
        applicant_pii: applicant_pii,
        ipp_enrollment_in_progress: ipp_enrollment_in_progress,
        request_ip: Faker::Internet.ip_v4_address,
        threatmetrix_session_id: threatmetrix_session_id,
        timer: JobHelpers::Timer.new,
        user_email: Faker::Internet.email,
        current_sp: current_sp,
      )
    end

    context 'remote proofing' do
      it 'returns a ResultAdjudicator' do
        expect(proof).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)
        expect(proof.same_address_as_id).to eq(nil)
      end

      context 'AAMVA raises an exception' do
        let(:aamva_proofer_result) do
          instance_double(
            Proofing::StateIdResult,
            success?: false,
            transaction_id: 'aamva-123',
            exception: RuntimeError.new('this is a fun test error!!'),
          )
        end

        it 'does not track an SP cost for AAMVA' do
          expect { proof }.to_not change { SpCost.where(cost_type: :aamva).count }
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
          allow(progressive_proofer).to receive(:with_state_id_address).and_return(transformed_pii)

          expect(proof.same_address_as_id).to eq('true')
          expect(proof.ipp_enrollment_in_progress).to eq(true)
          expect(proof.resolution_result).to eq(proof.residential_resolution_result)
          expect(proof.resolution_result.success?).to eq(true)
          expect(aamva_proofer).to have_received(:proof).with(transformed_pii)
        end

        it 'records a single LexisNexis SP cost and an AAMVA SP cost' do
          proof

          lexis_nexis_sp_costs = SpCost.where(
            cost_type: :lexis_nexis_resolution,
            issuer: current_sp.issuer,
          )
          aamva_sp_costs = SpCost.where(cost_type: :aamva, issuer: current_sp.issuer)

          expect(lexis_nexis_sp_costs.count).to eq(1)
          expect(aamva_sp_costs.count).to eq(1)
        end

        context 'LexisNexis InstantVerify fails' do
          let(:instant_verify_proofing_success) { false }

          before do
            allow(instant_verify_proofer_result).to(
              receive(
                :failed_result_can_pass_with_additional_verification?,
              ).and_return(true),
            )
          end

          it 'includes the state ID in the InstantVerify call' do
            expect(progressive_proofer).to receive(:user_can_pass_after_state_id_check?).
              and_call_original
            expect(instant_verify_proofer).to receive(:proof).
              with(hash_including(state_id_address))

            proof
          end

          context 'the failure can be covered by AAMVA' do
            context 'it is not covered by AAMVA' do
              let(:aamva_proofer_result)  do
                instance_double(
                  Proofing::StateIdResult,
                  verified_attributes: [],
                  success?: false,
                  transaction_id: 'aamva-123',
                  exception: nil,
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
                  transaction_id: 'aamva-123',
                  exception: nil,
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
              instance_double(
                Proofing::Resolution::Result,
                success?: true,
                transaction_id: 'aamva-123',
              )
            end

            before do
              allow(progressive_proofer).to receive(:proof_residential_address_if_needed).
                and_return(residential_resolution_that_passed_instant_verify)
            end

            it 'makes a request to the AAMVA proofer' do
              proof

              expect(aamva_proofer).to have_received(:proof)
            end

            context 'AAMVA proofing fails' do
              let(:aamva_client) { instance_double(Proofing::Aamva::VerificationClient) }
              let(:aamva_proofer_result) do
                instance_double(
                  Proofing::StateIdResult,
                  success?: false,
                  transaction_id: 'aamva-123',
                  exception: nil,
                )
              end

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
          instance_double(Proofing::Resolution::Result, transaction_id: 'residential-123')
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

            it 'records 2 LexisNexis SP cost and an AAMVA SP cost' do
              proof

              lexis_nexis_sp_costs = SpCost.where(
                cost_type: :lexis_nexis_resolution,
                issuer: current_sp.issuer,
              )
              aamva_sp_costs = SpCost.where(cost_type: :aamva, issuer: current_sp.issuer)

              expect(lexis_nexis_sp_costs.count).to eq(2)
              expect(aamva_sp_costs.count).to eq(1)
            end

            context 'AAMVA fails' do
              let(:aamva_proofer_result) do
                instance_double(
                  Proofing::StateIdResult,
                  success?: false,
                  transaction_id: 'aamva-123',
                  exception: nil,
                )
              end

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
            allow(progressive_proofer).to receive(:proof_residential_address_if_needed).
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
