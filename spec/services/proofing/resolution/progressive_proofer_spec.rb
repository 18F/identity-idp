require 'rails_helper'

RSpec.describe Proofing::Resolution::ProgressiveProofer do
  let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS }
  let(:should_proof_state_id) { true }
  let(:ipp_enrollment_in_progress) { true }
  let(:double_address_verification) { true }
  let(:request_ip) { Faker::Internet.ip_v4_address }
  let(:threatmetrix_session_id) { SecureRandom.uuid }
  let(:timer) { JobHelpers::Timer.new }
  let(:user) { create(:user, :fully_registered) }
  let(:instant_verify_proofer) { instance_double(Proofing::LexisNexis::InstantVerify::Proofer) }
  let(:dcs_uuid) { SecureRandom.uuid }
  let(:instance) { described_class.new(document_capture_session_uuid: dcs_uuid) }
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

  describe '#proof' do
    before do
      allow(IdentityConfig.store).to receive(:proofer_mock_fallback).and_return(false)
      allow(Proofing::LexisNexis::InstantVerify::VerificationRequest).to receive(:new)
    end
    subject(:proof) do
      instance.proof(
        applicant_pii: applicant_pii,
        ipp_enrollment_in_progress: ipp_enrollment_in_progress,
        double_address_verification: double_address_verification,
        request_ip: request_ip,
        should_proof_state_id: should_proof_state_id,
        threatmetrix_session_id: threatmetrix_session_id,
        timer: timer,
        user_email: user.confirmed_email_addresses.first.email,
      )
    end

    it 'returns a ResultAdjudicator' do
      proofing_result = proof

      expect(proofing_result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)
      expect(proofing_result.same_address_as_id).to eq(applicant_pii[:same_address_as_id])
    end

    let(:resolution_result) do
      instance_double(Proofing::Resolution::Result)
    end
    context 'ThreatMetrix is enabled' do
      let(:threatmetrix_proofer) { instance_double(Proofing::LexisNexis::Ddp::Proofer) }

      before do
        allow(FeatureManagement).to receive(:proofing_device_profiling_collecting_enabled?).
          and_return(true)
        allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_mock_enabled).
          and_return(false)
        allow(instance).to receive(:lexisnexis_ddp_proofer).and_return(threatmetrix_proofer)

        allow(instance).to receive(:proof_id_address_with_lexis_nexis_if_needed).
          and_return(resolution_result)
        allow(resolution_result).to receive(:success?).and_return(true)
        allow(instant_verify_proofer).to receive(:proof)
      end

      it 'makes a request to the ThreatMetrix proofer' do
        expect(threatmetrix_proofer).to receive(:proof)

        subject
      end

      context 'it lacks a session id' do
        let(:threatmetrix_session_id) { nil }
        it 'returns a disabled result' do
          result = subject

          device_profiling_result = result.device_profiling_result

          expect(device_profiling_result.success).to be(true)
          expect(device_profiling_result.client).to eq('tmx_disabled')
          expect(device_profiling_result.review_status).to eq('pass')
        end
      end
    end

    context 'ThreatMetrix is disabled' do
      before do
        allow(FeatureManagement).to receive(:proofing_device_profiling_collecting_enabled?).
          and_return(false)

        allow(instance).to receive(:proof_id_address_with_lexis_nexis_if_needed).
          and_return(resolution_result)
        allow(resolution_result).to receive(:success?).and_return(true)
        allow(instant_verify_proofer).to receive(:proof)
      end
      it 'returns a disabled result' do
        result = subject

        device_profiling_result = result.device_profiling_result

        expect(device_profiling_result.success).to be(true)
        expect(device_profiling_result.client).to eq('tmx_disabled')
        expect(device_profiling_result.review_status).to eq('pass')
      end
    end

    context 'LexisNexis Instant Verify A/B test enabled' do
      let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID }
      let(:residential_instant_verify_proof) do
        instance_double(Proofing::Resolution::Result)
      end
      let(:instant_verify_workflow) { 'equitable_workflow' }
      let(:ab_test_variables) do
        {
          ab_testing_enabled: true,
          use_alternate_workflow: true,
          instant_verify_workflow: instant_verify_workflow,
        }
      end

      before do
        allow(instant_verify_proofer).to receive(:proof).
          and_return(residential_instant_verify_proof)
        allow(residential_instant_verify_proof).to receive(:success?).and_return(true)
      end

      it 'uses the selected workflow' do
        lniv = Idv::LexisnexisInstantVerify.new(dcs_uuid)
        expect(lniv).to receive(:workflow_ab_testing_variables).
          and_return(ab_test_variables)
        expect(Idv::LexisnexisInstantVerify).to receive(:new).
          and_return(lniv)
        expect(Proofing::LexisNexis::InstantVerify::Proofer).to receive(:new).
          with(hash_including(instant_verify_workflow: instant_verify_workflow)).
          and_return(instant_verify_proofer)

        proof
      end
    end

    context 'residential address and id address are the same' do
      let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID }
      let(:aamva_proofer) { instance_double(Proofing::Aamva::Proofer) }
      let(:residential_instant_verify_proof) do
        instance_double(Proofing::Resolution::Result)
      end
      before do
        allow(instance).to receive(:state_id_proofer).and_return(aamva_proofer)
        allow(instance).to receive(:resolution_proofer).and_return(instant_verify_proofer)
        allow(instant_verify_proofer).to receive(:proof).
          and_return(residential_instant_verify_proof)
        allow(residential_instant_verify_proof).to receive(:success?).and_return(true)
      end

      it 'only makes one request to LexisNexis InstantVerify' do
        expect(instant_verify_proofer).to receive(:proof).exactly(:once)
        expect(aamva_proofer).to receive(:proof)

        subject
      end

      it 'produces a result adjudicator with correct information' do
        expect(aamva_proofer).to receive(:proof)

        result = subject

        expect(result.same_address_as_id).to eq('true')
        expect(result.ipp_enrollment_in_progress).to eq(true)
        expect(result.double_address_verification).to eq(true)
        expect(result.resolution_result).to eq(result.residential_resolution_result)
      end

      context 'LexisNexis InstantVerify fails' do
        let(:result_that_failed_instant_verify) do
          instance_double(Proofing::Resolution::Result)
        end
        before do
          allow(instance).to receive(:proof_id_address_with_lexis_nexis_if_needed).
            and_return(result_that_failed_instant_verify)
          allow(instant_verify_proofer).to receive(:proof).with(hash_including(state_id_address)).
            and_return(result_that_failed_instant_verify)
          allow(instance).to receive(:user_can_pass_after_state_id_check?).
            with(result_that_failed_instant_verify).
            and_return(true)
          allow(result_that_failed_instant_verify).to receive(:success?).
            and_return(false)
        end

        context 'the failure can be covered by AAMVA' do
          before do
            allow(result_that_failed_instant_verify).
              to receive(:attributes_requiring_additional_verification).
              and_return([:address])
          end

          context 'it is not covered by AAMVA' do
            let(:failed_aamva_proof) { instance_double(Proofing::StateIdResult) }
            before do
              allow(aamva_proofer).to receive(:proof).and_return(failed_aamva_proof)
              allow(failed_aamva_proof).to receive(:verified_attributes).and_return([])
              allow(failed_aamva_proof).to receive(:success?).and_return(false)
            end
            it 'indicates the aamva check did not pass' do
              result = subject

              expect(result.state_id_result.success?).to eq(false)
            end
          end

          context 'it is covered by AAMVA' do
            let(:successful_aamva_proof) { instance_double(Proofing::StateIdResult) }
            before do
              allow(aamva_proofer).to receive(:proof).and_return(successful_aamva_proof)
              allow(successful_aamva_proof).to receive(:verified_attributes).
                and_return([:address])
              allow(successful_aamva_proof).to receive(:success?).and_return(true)
            end
            it 'indicates aamva did pass' do
              result = subject

              expect(result.state_id_result.success?).to eq(true)
            end
          end
        end
      end

      context 'LexisNexis InstantVerify passes for residential address and id address' do
        context 'should proof with AAMVA' do
          let(:id_resolution_that_passed_instant_verify) do
            instance_double(Proofing::Resolution::Result)
          end
          let(:residential_resolution_that_passed_instant_verify) do
            instance_double(Proofing::Resolution::Result)
          end

          before do
            allow(instance).to receive(:proof_residential_address_if_needed).
              and_return(residential_resolution_that_passed_instant_verify)
            allow(instance).to receive(:proof_id_address_with_lexis_nexis_if_needed).
              and_return(id_resolution_that_passed_instant_verify)
            allow(instant_verify_proofer).to receive(:proof).
              with(hash_including(state_id_address)).
              and_return(id_resolution_that_passed_instant_verify)
            allow(instance).to receive(:user_can_pass_after_state_id_check?).
              with(id_resolution_that_passed_instant_verify).
              and_return(true)
            allow(id_resolution_that_passed_instant_verify).to receive(:success?).
              and_return(true)
            allow(residential_resolution_that_passed_instant_verify).to receive(:success?).
              and_return(true)
          end

          it 'makes a request to the AAMVA proofer' do
            expect(aamva_proofer).to receive(:proof)

            subject
          end

          context 'AAMVA proofing fails' do
            let(:aamva_client) { instance_double(Proofing::Aamva::VerificationClient) }
            let(:failed_aamva_proof) do
              instance_double(Proofing::StateIdResult)
            end
            before do
              allow(Proofing::Aamva::VerificationClient).to receive(:new).and_return(aamva_client)
              allow(failed_aamva_proof).to receive(:success?).and_return(false)
            end
            it 'returns a result adjudicator that indicates the aamva proofing failed' do
              allow(aamva_proofer).to receive(:proof).and_return(failed_aamva_proof)

              result = subject

              expect(result.state_id_result.success?).to eq(false)
            end
          end
        end
      end
    end

    context 'residential address and id address are different' do
      let(:residential_address_proof) do
        instance_double(Proofing::Resolution::Result)
      end
      let(:resolution_result) do
        instance_double(Proofing::Resolution::Result)
      end
      let(:ipp_enrollment_in_progress) { true }
      let(:double_address_verification) { true }
      let(:applicant_pii) do
        JSON.parse(<<-STR, symbolize_names: true)
            {
              "uuid": "3e8db152-4d35-4207-b828-3eee8c52c50f",
              "middle_name": "",
              "phone": "",
              "state_id_expiration": "2029-01-01",
              "state_id_issued": "MI",
              "first_name": "Imaginary",
              "last_name": "Person",
              "dob": "1999-09-00",
              "identity_doc_address1": "1 Seaview",
              "identity_doc_address2": "",
              "identity_doc_city": "Sant Cruz",
              "identity_doc_zipcode": "91000",
              "state_id_jurisdiction": "AZ",
              "identity_doc_address_state": "CA",
              "state_id_number": "AZ333222111",
              "same_address_as_id": "false",
              "state": "MI",
              "zipcode": "48880",
              "city": "Pontiac",
              "address1": "1 Mobile Dr",
              "address2": "",
              "ssn": "900-32-1898",
              "state_id_type": "drivers_license",
              "uuid_prefix": null
            }
        STR
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
        before do
          allow(instance).to receive(:resolution_proofer).and_return(instant_verify_proofer)
          allow(instant_verify_proofer).to receive(:proof).and_return(residential_address_proof)
          allow(residential_address_proof).to receive(:success?).and_return(true)
        end

        context 'LexisNexis InstantVerify passes for id address' do
          it 'makes two requests to the InstantVerify Proofer' do
            expect(instant_verify_proofer).to receive(:proof).
              with(hash_including(residential_address)).
              ordered
            expect(instant_verify_proofer).to receive(:proof).
              with(hash_including(state_id_address)).
              ordered

            subject
          end

          context 'AAMVA fails' do
            let(:failed_aamva_proof) { instance_double(Proofing::StateIdResult) }
            let(:aamva_proofer) { instance_double(Proofing::Aamva::Proofer) }
            before do
              allow(instance).to receive(:proof_id_with_aamva_if_needed).
                and_return(failed_aamva_proof)
              allow(aamva_proofer).to receive(:proof).and_return(failed_aamva_proof)
              allow(failed_aamva_proof).to receive(:success?).and_return(false)
              allow(resolution_result).to receive(:errors)
            end

            it 'returns the correct resolution results' do
              result_adjudicator = subject

              expect(result_adjudicator.residential_resolution_result.success?).to be(true)
              expect(result_adjudicator.resolution_result.success?).to be(true)
              expect(result_adjudicator.state_id_result.success?).to be(false)
            end
          end
        end
      end

      context 'LexisNexis InstantVerify fails for residential address' do
        let(:aamva_proofer) { instance_double(Proofing::Aamva::Proofer) }

        before do
          allow(instance).to receive(:state_id_proofer).and_return(aamva_proofer)
          allow(instance).to receive(:proof_residential_address_if_needed).
            and_return(residential_address_proof)
          allow(instant_verify_proofer).to receive(:proof).
            with(hash_including(residential_address)).
            and_return(residential_address_proof)
          allow(instance).to receive(:user_can_pass_after_state_id_check?).
            with(residential_address_proof).
            and_return(false)
          allow(residential_address_proof).to receive(:success?).
            and_return(false)
        end

        it 'does not make unnecessary calls' do
          expect(aamva_proofer).to_not receive(:proof)
          expect(instant_verify_proofer).to_not receive(:proof).
            with(hash_including(state_id_address))

          subject
        end
      end

      context 'LexisNexis InstantVerify fails for id address & passes for residential address' do
        let(:aamva_proofer) { instance_double(Proofing::Aamva::Proofer) }
        let(:result_that_failed_instant_verify) do
          instance_double(Proofing::Resolution::Result)
        end

        before do
          allow(instance).to receive(:state_id_proofer).and_return(aamva_proofer)
          allow(instance).to receive(:proof_id_address_with_lexis_nexis_if_needed).
            and_return(result_that_failed_instant_verify)
          allow(instant_verify_proofer).to receive(:proof).with(hash_including(state_id_address)).
            and_return(result_that_failed_instant_verify)
        end

        context 'the failure can be covered by AAMVA' do
          let(:failed_aamva_proof) { instance_double(Proofing::StateIdResult) }
          let(:aamva_proofer) { instance_double(Proofing::Aamva::Proofer) }
          before do
            allow(instance).to receive(:resolution_proofer).and_return(instant_verify_proofer)
            allow(instant_verify_proofer).to receive(:proof).and_return(residential_address_proof)
            allow(residential_address_proof).to receive(:success?).and_return(true)

            allow(instance).to receive(:user_can_pass_after_state_id_check?).
              with(result_that_failed_instant_verify).
              and_return(true)
            allow(result_that_failed_instant_verify).
              to receive(:attributes_requiring_additional_verification).
              and_return([:address])
            allow(instance).to receive(:state_id_proofer).and_return(aamva_proofer)
          end
          it 'calls AAMVA' do
            expect(aamva_proofer).to receive(:proof)

            subject
          end
        end
      end
    end
  end
end
