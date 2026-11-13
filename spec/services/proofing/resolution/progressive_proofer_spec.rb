require 'rails_helper'

RSpec.describe Proofing::Resolution::ProgressiveProofer do
  let(:user) { build(:user) }
  let(:user_uuid) { user.uuid }
  let(:user_email) { user.email }
  let(:proofing_vendor) { :mock }
  let(:idv_phone_precheck_percent) { 100 }
  let(:analytics) { FakeAnalytics.new }
  let(:threatmetrix_ddp_policy) { 'TEST_POLICY' }
  let(:threatmetrix_hybrid_ddp_policy) { 'HYBRID_TEST_POLICY' }

  subject(:progressive_proofer) do
    described_class.new(user_uuid:, proofing_vendor:, analytics:, user_email:)
  end

  it 'assigns threatmetrix_plugin' do
    expect(
      progressive_proofer.threatmetrix_plugin,
    ).to be_a(
      Proofing::Resolution::Plugins::ThreatMetrixPlugin,
    )
  end

  describe '#proof' do
    let(:applicant_pii) { { uuid: user.uuid }.merge(Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE) }
    let(:ipp_enrollment_in_progress) { false }
    let(:request_ip) { Faker::Internet.ip_v4_address }
    let(:threatmetrix_session_id) { SecureRandom.uuid }
    let(:current_sp) { build(:service_provider) }
    let(:workflow) { :idv }

    let(:residential_address_resolution_result) do
      Proofing::Resolution::Result.new(
        success: true,
        transaction_id: 'residential-resolution-tx',
      )
    end

    let(:state_id_address_resolution_result) do
      Proofing::Resolution::Result.new(
        success: true,
        transaction_id: 'state-id-resolution-tx',
      )
    end

    let(:resolution_proofing_results) do
      # No call is made for residential address on remote unsupervised path
      [state_id_address_resolution_result]
    end

    let(:resolution_proofer) do
      instance_double(
        Proofing::LexisNexis::InstantVerify::Proofer,
      )
    end

    let(:threatmetrix_result) do
      Proofing::DdpResult.new(
        success: true,
        transaction_id: 'ddp-123',
      )
    end

    let(:threatmetrix_proofer) do
      instance_double(
        Proofing::LexisNexis::Ddp::Proofers::ThreatMetrixProofer,
        proof: threatmetrix_result,
      )
    end

    let(:hybrid_device_profiling) { :disabled }
    let(:hybrid_mobile_threatmetrix_session_id) { nil }
    let(:hybrid_mobile_request_ip) { nil }
    let(:hybrid_mobile_threatmetrix_result) do
      Proofing::DdpResult.new(
        success: true,
        transaction_id: 'hybrid-mobile-ddp-123',
        review_status: 'pass',
      )
    end

    subject(:proof) do
      progressive_proofer.proof(
        applicant_pii:,
        ipp_enrollment_in_progress:,
        request_ip:,
        threatmetrix_session_id:,
        timer: JobHelpers::Timer.new,
        current_sp:,
        workflow:,
        hybrid_mobile_threatmetrix_session_id:,
        hybrid_mobile_request_ip:,
      )
    end

    before do
      allow(resolution_proofer).to receive(:proof).and_return(*resolution_proofing_results)
      allow(progressive_proofer).to receive(:create_proofer)
        .and_return(resolution_proofer)

      allow(progressive_proofer.threatmetrix_plugin).to receive(:proofer)
        .and_return(threatmetrix_proofer)

      allow(IdentityConfig.store).to receive_messages(
        idv_phone_precheck_percent: idv_phone_precheck_percent,
        proofing_device_hybrid_profiling: hybrid_device_profiling,
        lexisnexis_threatmetrix_policy: threatmetrix_ddp_policy,
        lexisnexis_threatmetrix_hybrid_handoff_policy: threatmetrix_hybrid_ddp_policy,
      )
    end

    context 'remote unsupervised proofing' do
      it 'calls ResidentialAddressPlugin' do
        expect(progressive_proofer.residential_address_plugin).to receive(:call).with(
          applicant_pii:,
          current_sp:,
          ipp_enrollment_in_progress: false,
          timer: an_instance_of(JobHelpers::Timer),
        ).and_call_original
        proof
      end

      it 'calls StateIdAddressPlugin' do
        expect(progressive_proofer.state_id_address_plugin).to receive(:call).with(
          applicant_pii:,
          current_sp:,
          residential_address_resolution_result: satisfy do |result|
            expect(result.success?).to eql(true)
            expect(result.vendor_name).to eql('ResidentialAddressNotRequired')
          end,
          ipp_enrollment_in_progress: false,
          timer: an_instance_of(JobHelpers::Timer),
        ).and_call_original
        proof
      end

      it 'calls ThreatMetrixPlugin' do
        expect(progressive_proofer.threatmetrix_plugin).to receive(:call).with(
          applicant_pii:,
          current_sp:,
          request_ip:,
          threatmetrix_session_id:,
          timer: an_instance_of(JobHelpers::Timer),
          user_email:,
          user_uuid:,
          workflow:,
          ddp_policy: threatmetrix_ddp_policy,
        )
        proof
      end

      context 'with hybrid mobile device profiling enabled' do
        let(:hybrid_device_profiling) { :enabled }
        let(:hybrid_mobile_threatmetrix_session_id) { SecureRandom.uuid }
        let(:hybrid_mobile_request_ip) { Faker::Internet.ip_v4_address }

        before do
          allow(progressive_proofer.threatmetrix_plugin).to receive(:call)
            .and_return(threatmetrix_result, hybrid_mobile_threatmetrix_result)
        end

        it 'calls ThreatMetrixPlugin twice with desktop and hybrid session data' do
          expect(progressive_proofer.threatmetrix_plugin).to receive(:call).with(
            applicant_pii:,
            current_sp:,
            request_ip:,
            threatmetrix_session_id:,
            timer: an_instance_of(JobHelpers::Timer),
            user_email:,
            user_uuid:,
            workflow:,
            ddp_policy: threatmetrix_ddp_policy,
          ).ordered

          expect(progressive_proofer.threatmetrix_plugin).to receive(:call).with(
            applicant_pii:,
            current_sp:,
            request_ip: hybrid_mobile_request_ip,
            threatmetrix_session_id: hybrid_mobile_threatmetrix_session_id,
            timer: an_instance_of(JobHelpers::Timer),
            user_email:,
            user_uuid:,
            workflow: :"#{workflow}_hybrid_handoff",
            ddp_policy: threatmetrix_hybrid_ddp_policy,
          ).ordered

          proof
        end

        it 'returns a ResultAdjudicator with hybrid_mobile_device_profiling_result' do
          proof.tap do |result|
            expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)
            expect(result.device_profiling_result).to eql(threatmetrix_result)
            expect(result.hybrid_mobile_device_profiling_result)
              .to eql(hybrid_mobile_threatmetrix_result)
          end
        end
      end

      context 'with hybrid mobile device profiling disabled' do
        let(:hybrid_device_profiling) { :disabled }

        it 'calls ThreatMetrixPlugin only once' do
          expect(progressive_proofer.threatmetrix_plugin).to receive(:call).once
          proof
        end

        it 'returns a ResultAdjudicator with nil hybrid_mobile_device_profiling_result' do
          proof.tap do |result|
            expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)
            expect(result.device_profiling_result).to eql(threatmetrix_result)
            expect(result.hybrid_mobile_device_profiling_result).to be_nil
          end
        end
      end

      context 'with hybrid mobile device profiling enabled but without session ID' do
        let(:hybrid_device_profiling) { :enabled }
        let(:hybrid_mobile_threatmetrix_session_id) { nil }
        let(:hybrid_mobile_request_ip) { Faker::Internet.ip_v4_address }

        it 'calls ThreatMetrixPlugin twice (user went through hybrid flow)' do
          expect(progressive_proofer.threatmetrix_plugin).to receive(:call).twice
          proof
        end

        it 'returns a ResultAdjudicator with threatmetrix_id_missing_result' do
          proof.tap do |result|
            expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)
            expect(result.device_profiling_result).to eql(threatmetrix_result)
            expect(result.hybrid_mobile_device_profiling_result).to be_present
            expect(result.hybrid_mobile_device_profiling_result.success).to be false
            expect(result.hybrid_mobile_device_profiling_result.client)
              .to eq('tmx_session_id_missing')
            expect(result.hybrid_mobile_device_profiling_result.review_status).to eq('reject')
          end
        end
      end

      it 'returns a ResultAdjudicator' do
        proof.tap do |result|
          expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)

          expect(result.resolution_result).to eql(state_id_address_resolution_result)
          expect(result.device_profiling_result).to eql(threatmetrix_result)
          expect(result.phone_result[:alternate_result]).to be_nil
          expect(result.phone_result[:success]).to eq(true)
          expect(result.phone_result[:vendor_name]).to eq('AddressMock')
          expect(result.residential_resolution_result).to satisfy do |result|
            expect(result.success?).to eql(true)
            expect(result.vendor_name).to eql('ResidentialAddressNotRequired')
          end
          expect(result.ipp_enrollment_in_progress).to eql(false)
          expect(result.ipp_current_address_matches_id).to eql(nil)
        end
      end

      context 'when state_id address resolution fails' do
        let(:state_id_address_resolution_result) do
          Proofing::Resolution::Result.new(
            success: false,
            transaction_id: 'state-id-resolution-failed-tx',
          )
        end
      end

      context 'when threatmetrix fails' do
        before do
          allow(threatmetrix_proofer).to receive(:proof).and_return(
            Proofing::DdpResult.new(
              success: false,
              transaction_id: 'ddp-failed-123',
            ),
          )
        end
        it 'phone precheck still runs' do
          expect(Proofing::Mock::AddressMockClient).to receive(:new).and_call_original

          proof.tap do |result|
            expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)
            expect(result.resolution_result).to eql(state_id_address_resolution_result)
            expect(result.device_profiling_result.success?).to be_falsey
            expect(result.device_profiling_result.transaction_id).to eq('ddp-failed-123')
            expect(result.phone_result[:alternate_result]).to be_nil
            expect(result.phone_result[:success]).to eq(true)
            expect(result.phone_result[:vendor_name]).to eq('AddressMock')
          end
        end
      end

      context 'when hybrid mobile threatmetrix fails' do
        let(:hybrid_device_profiling) { :enabled }
        let(:hybrid_mobile_threatmetrix_session_id) { SecureRandom.uuid }
        let(:hybrid_mobile_request_ip) { Faker::Internet.ip_v4_address }
        let(:hybrid_mobile_threatmetrix_result) do
          Proofing::DdpResult.new(
            success: false,
            transaction_id: 'hybrid-mobile-ddp-failed-123',
            review_status: 'fail',
          )
        end

        before do
          allow(progressive_proofer.threatmetrix_plugin).to receive(:call)
            .and_return(threatmetrix_result, hybrid_mobile_threatmetrix_result)
        end

        it 'returns a ResultAdjudicator with the failed hybrid mobile result' do
          proof.tap do |result|
            expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)
            expect(result.device_profiling_result.success?).to be_truthy
            expect(result.hybrid_mobile_device_profiling_result.success?).to be_falsey
            expect(result.hybrid_mobile_device_profiling_result.transaction_id)
              .to eq('hybrid-mobile-ddp-failed-123')
          end
        end

        it 'still allows phone precheck to run' do
          expect(Proofing::Mock::AddressMockClient).to receive(:new).and_call_original
          proof
        end
      end

      context 'when hybrid mobile threatmetrix times out' do
        let(:hybrid_device_profiling) { :enabled }
        let(:hybrid_mobile_threatmetrix_session_id) { SecureRandom.uuid }
        let(:hybrid_mobile_request_ip) { Faker::Internet.ip_v4_address }
        let(:hybrid_mobile_threatmetrix_result) do
          result = Proofing::DdpResult.new(
            success: false,
            transaction_id: 'hybrid-mobile-ddp-timeout-123',
            review_status: 'fail',
          )
          allow(result).to receive(:timed_out?).and_return(true)
          result
        end

        before do
          allow(progressive_proofer.threatmetrix_plugin).to receive(:call)
            .and_return(threatmetrix_result, hybrid_mobile_threatmetrix_result)
        end

        it 'returns a ResultAdjudicator with the timed out hybrid mobile result' do
          proof.tap do |result|
            expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)
            expect(result.hybrid_mobile_device_profiling_result.timed_out?).to be_truthy
          end
        end
      end

      context 'when both regular and hybrid mobile threatmetrix fail' do
        let(:hybrid_device_profiling) { :enabled }
        let(:hybrid_mobile_threatmetrix_session_id) { SecureRandom.uuid }
        let(:hybrid_mobile_request_ip) { Faker::Internet.ip_v4_address }
        let(:threatmetrix_result) do
          Proofing::DdpResult.new(
            success: false,
            transaction_id: 'ddp-failed-123',
            review_status: 'fail',
          )
        end
        let(:hybrid_mobile_threatmetrix_result) do
          Proofing::DdpResult.new(
            success: false,
            transaction_id: 'hybrid-mobile-ddp-failed-123',
            review_status: 'fail',
          )
        end

        before do
          allow(progressive_proofer.threatmetrix_plugin).to receive(:call)
            .and_return(threatmetrix_result, hybrid_mobile_threatmetrix_result)
        end

        it 'returns a ResultAdjudicator with both failed results' do
          proof.tap do |result|
            expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)
            expect(result.device_profiling_result.success?).to be_falsey
            expect(result.hybrid_mobile_device_profiling_result.success?).to be_falsey
          end
        end
      end

      context 'when precheck is not enabled' do
        let(:idv_phone_precheck_percent) { 0 }
        it 'returns a ResultAdjudicator' do
          proof.tap do |result|
            expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)

            expect(result.resolution_result).to eql(state_id_address_resolution_result)
            expect(result.device_profiling_result).to eql(threatmetrix_result)
            expect(result.phone_result).to be_empty
            expect(result.residential_resolution_result).to satisfy do |result|
              expect(result.success?).to eql(true)
              expect(result.vendor_name).to eql('ResidentialAddressNotRequired')
            end
            expect(result.ipp_enrollment_in_progress).to eql(false)
            expect(result.ipp_current_address_matches_id).to eql(nil)
          end
        end
      end
    end

    context 'Instant Verify failure bypass' do
      let(:is_proofing_agent) { true }
      let(:ipp_enrollment_in_progress) { true }
      let(:bypass_error_codes) { ['dob'] }
      let(:ssa_proofing_agent_as_authoritative_source) { true }
      let(:proofing_vendor) { :instant_verify }
      let(:failed_checks) { [{ 'ItemName' => 'DOBFullVerified', 'ItemStatus' => 'fail' }] }
      let(:instant_verify_errors) do
        {
          InstantVerify: {
            'ProductType' => 'InstantVerify',
            'ProductStatus' => 'fail',
            'Items' => failed_checks,
          },
        }
      end
      let(:applicant_pii) do
        { uuid: user.uuid }.merge(Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID_WITH_PHONE)
      end
      let(:residential_address_resolution_result) do
        Proofing::Resolution::Result.new(
          success: false,
          errors: instant_verify_errors,
          vendor_name: 'lexisnexis:instant_verify',
          transaction_id: 'failed-instant-verify-tx',
        )
      end
      let(:state_id_address_resolution_result) { residential_address_resolution_result }
      let(:resolution_proofing_results) { [residential_address_resolution_result] }

      subject(:progressive_proofer) do
        described_class.new(
          user_uuid:, proofing_vendor:, analytics:, user_email:, is_proofing_agent:,
        )
      end

      before do
        allow(IdentityConfig.store).to receive_messages(
          ssa_instant_verify_bypass_error_codes: bypass_error_codes,
          ssa_proofing_agent_as_authoritative_source:,
        )
        allow(Db::SpCost::AddSpCost).to receive(:call)
      end

      context 'when Instant Verify failed only on bypassable checks' do
        it 'treats the resolution and residential address as passing and runs phone proofing' do
          result = proof.adjudicated_result

          expect(result.success?).to eq(true)
          expect(result.extra[:context][:resolution_adjudication_reason])
            .to eq(:instant_verify_bypass)
          expect(result.extra[:context][:stages][:resolution])
            .to include(success: true, bypassed: true, transaction_id: 'failed-instant-verify-tx')
          expect(result.extra[:context][:stages][:residential_address])
            .to include(success: true, transaction_id: 'failed-instant-verify-tx')
          expect(result.extra[:context][:stages][:phone_precheck])
            .to include(success: true, vendor_name: 'AddressMock')
          expect(result.extra[:phone_precheck_passed]).to eq(true)
        end

        it 'keeps the original errors' do
          result = proof.adjudicated_result

          expect(result.errors).to eq(instant_verify_errors)
        end
      end

      context 'when a failed check is not bypassable' do
        let(:failed_checks) do
          super() + [{ 'ItemName' => 'IdentityOccupancyVerified', 'ItemStatus' => 'fail' }]
        end

        it 'does not bypass the failure' do
          result = proof.adjudicated_result

          expect(result.success?).to eq(false)
          expect(result.extra[:context][:resolution_adjudication_reason])
            .to eq(:fail_resolution_without_state_id_coverage)
          expect(result.extra[:context][:stages][:resolution]).not_to have_key(:bypassed)
          expect(result.extra[:context][:stages][:phone_precheck][:vendor_name])
            .to eq('ResolutionCannotPass')
        end
      end

      context 'when ssa_proofing_agent_as_authoritative_source is disabled' do
        let(:ssa_proofing_agent_as_authoritative_source) { false }

        it 'does not bypass the failure' do
          result = proof.adjudicated_result

          expect(result.success?).to eq(false)
          expect(result.extra[:context][:resolution_adjudication_reason])
            .to eq(:fail_resolution_without_state_id_coverage)
          expect(result.extra[:context][:stages][:resolution]).not_to have_key(:bypassed)
          expect(result.extra[:context][:stages][:phone_precheck][:vendor_name])
            .to eq('ResolutionCannotPass')
        end
      end

      %i[instant_verify instant_verify_ddp].each do |instant_verify_vendor|
        context "when the proofing vendor is #{instant_verify_vendor}" do
          let(:proofing_vendor) { instant_verify_vendor }

          it 'bypasses the failure' do
            result = proof.adjudicated_result

            expect(result.success?).to eq(true)
            expect(result.extra[:context][:resolution_adjudication_reason])
              .to eq(:instant_verify_bypass)
          end
        end
      end

      %i[mock socure_kyc].each do |other_vendor|
        context "when the proofing vendor is #{other_vendor}" do
          let(:proofing_vendor) { other_vendor }

          it 'does not bypass the failure' do
            result = proof.adjudicated_result

            expect(result.success?).to eq(false)
            expect(result.extra[:context][:stages][:resolution]).not_to have_key(:bypassed)
          end
        end
      end

      context 'when the proofer is not a proofing agent' do
        let(:is_proofing_agent) { false }

        it 'does not bypass the failure' do
          result = proof.adjudicated_result

          expect(result.success?).to eq(false)
          expect(result.extra[:context][:stages][:resolution]).not_to have_key(:bypassed)
        end
      end

      context 'when the residential address is different and passes' do
        let(:applicant_pii) do
          { uuid: user.uuid }.merge(Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE)
        end
        let(:residential_address_resolution_result) do
          Proofing::Resolution::Result.new(success: true, transaction_id: 'residential-tx')
        end
        let(:state_id_address_resolution_result) do
          Proofing::Resolution::Result.new(
            success: false,
            errors: instant_verify_errors,
            vendor_name: 'lexisnexis:instant_verify',
            transaction_id: 'failed-instant-verify-tx',
          )
        end
        let(:resolution_proofing_results) do
          [residential_address_resolution_result, state_id_address_resolution_result]
        end

        it 'bypasses the state ID address failure' do
          result = proof.adjudicated_result

          expect(result.success?).to eq(true)
          expect(result.extra[:context][:resolution_adjudication_reason])
            .to eq(:instant_verify_bypass)
        end
      end

      context 'when the residential address is different and fails' do
        let(:applicant_pii) do
          { uuid: user.uuid }.merge(Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE)
        end
        let(:resolution_proofing_results) { [residential_address_resolution_result] }

        it 'does not bypass the failure' do
          result = proof.adjudicated_result

          expect(result.success?).to eq(false)
          expect(result.extra[:context][:resolution_adjudication_reason])
            .to eq(:fail_resolution_without_state_id_coverage)
        end
      end
    end

    context 'in-person proofing' do
      let(:ipp_enrollment_in_progress) { true }

      let(:resolution_proofing_results) do
        # In cases where both calls are made, the residential call is made
        # before the state id address call
        [residential_address_resolution_result, state_id_address_resolution_result]
      end

      context 'residential address is same as id' do
        let(:applicant_pii) do
          { uuid: user.uuid }.merge(Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID)
        end

        let(:state_id_address_resolution_result) do
          residential_address_resolution_result
        end

        it 'calls ResidentialAddressPlugin' do
          expect(progressive_proofer.residential_address_plugin).to receive(:call).with(
            applicant_pii:,
            current_sp:,
            ipp_enrollment_in_progress: true,
            timer: an_instance_of(JobHelpers::Timer),
          ).and_call_original
          proof
        end

        it 'calls StateIdAddressPlugin' do
          expect(progressive_proofer.state_id_address_plugin).to receive(:call).with(
            applicant_pii:,
            current_sp:,
            residential_address_resolution_result:,
            ipp_enrollment_in_progress: true,
            timer: an_instance_of(JobHelpers::Timer),
          ).and_call_original
          proof
        end

        it 'calls ThreatMetrixPlugin' do
          expect(progressive_proofer.threatmetrix_plugin).to receive(:call).with(
            applicant_pii:,
            current_sp:,
            request_ip:,
            threatmetrix_session_id:,
            timer: an_instance_of(JobHelpers::Timer),
            user_email:,
            user_uuid:,
            workflow:,
            ddp_policy: threatmetrix_ddp_policy,
          )
          proof
        end

        context 'with hybrid mobile device profiling enabled' do
          let(:hybrid_device_profiling) { :enabled }
          let(:hybrid_mobile_threatmetrix_session_id) { SecureRandom.uuid }
          let(:hybrid_mobile_request_ip) { Faker::Internet.ip_v4_address }

          before do
            allow(progressive_proofer.threatmetrix_plugin).to receive(:call)
              .and_return(threatmetrix_result, hybrid_mobile_threatmetrix_result)
          end

          it 'returns a ResultAdjudicator with both device profiling results' do
            proof.tap do |result|
              expect(result.device_profiling_result).to eql(threatmetrix_result)
              expect(result.hybrid_mobile_device_profiling_result)
                .to eql(hybrid_mobile_threatmetrix_result)
            end
          end
        end

        it 'calls PhonePlugin' do
          expect(progressive_proofer.phone_plugin).to receive(:call).with(
            applicant_pii:,
            current_sp:,
            residential_address_resolution_result:,
            state_id_address_resolution_result:,
            timer: an_instance_of(JobHelpers::Timer),
            best_effort_phone: nil,
            user_email:,
            is_proofing_agent: false,
          ).and_call_original
          proof
        end

        it 'returns a ResultAdjudicator' do
          proof.tap do |result|
            expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)

            expect(result.resolution_result).to eql(state_id_address_resolution_result)
            expect(result.device_profiling_result).to eql(threatmetrix_result)
            expect(result.phone_result[:alternate_result]).to be_nil
            expect(result.phone_result[:success]).to be_falsey
            expect(result.phone_result[:vendor_name]).to eq('NoPhoneNumberAvailable')
            expect(result.residential_resolution_result).to(
              eql(state_id_address_resolution_result),
            )
            expect(result.ipp_enrollment_in_progress).to eql(true)
            expect(proof.ipp_current_address_matches_id)
              .to eq(applicant_pii[:ipp_current_address_matches_id])
          end
        end

        context 'when phone precheck is not enabled' do
          let(:idv_phone_precheck_percent) { 0 }
          it 'returns a ResultAdjudicator' do
            proof.tap do |result|
              expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)

              expect(result.resolution_result).to eql(state_id_address_resolution_result)
              expect(result.device_profiling_result).to eql(threatmetrix_result)
              expect(result.phone_result).to be_empty
              expect(result.residential_resolution_result).to(
                eql(state_id_address_resolution_result),
              )
              expect(result.ipp_enrollment_in_progress).to eql(true)
              expect(proof.ipp_current_address_matches_id)
                .to eq(applicant_pii[:ipp_current_address_matches_id])
            end
          end
        end
      end

      context 'residential address is different than id' do
        let(:applicant_pii) do
          { uuid: user.uuid }.merge(Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS)
        end

        it 'calls ThreatMetrixPlugin' do
          expect(progressive_proofer.threatmetrix_plugin).to receive(:call).with(
            applicant_pii:,
            current_sp:,
            request_ip:,
            threatmetrix_session_id:,
            timer: an_instance_of(JobHelpers::Timer),
            user_email:,
            user_uuid:,
            workflow:,
            ddp_policy: threatmetrix_ddp_policy,
          )
          proof
        end

        context 'with hybrid mobile device profiling enabled' do
          let(:hybrid_device_profiling) { :enabled }
          let(:hybrid_mobile_threatmetrix_session_id) { SecureRandom.uuid }
          let(:hybrid_mobile_request_ip) { Faker::Internet.ip_v4_address }

          before do
            allow(progressive_proofer.threatmetrix_plugin).to receive(:call)
              .and_return(threatmetrix_result, hybrid_mobile_threatmetrix_result)
          end

          it 'returns a ResultAdjudicator with both device profiling results' do
            proof.tap do |result|
              expect(result.device_profiling_result).to eql(threatmetrix_result)
              expect(result.hybrid_mobile_device_profiling_result)
                .to eql(hybrid_mobile_threatmetrix_result)
            end
          end
        end

        it 'calls ResidentialAddressPlugin' do
          expect(progressive_proofer.residential_address_plugin).to receive(:call).with(
            applicant_pii:,
            current_sp:,
            ipp_enrollment_in_progress: true,
            timer: an_instance_of(JobHelpers::Timer),
          ).and_call_original
          proof
        end

        it 'calls StateIdAddressPlugin' do
          expect(progressive_proofer.state_id_address_plugin).to receive(:call).with(
            applicant_pii:,
            current_sp:,
            residential_address_resolution_result:,
            ipp_enrollment_in_progress: true,
            timer: an_instance_of(JobHelpers::Timer),
          ).and_call_original
          proof
        end

        it 'calls PhonePlugin' do
          expect(progressive_proofer.phone_plugin).to receive(:call).with(
            applicant_pii:,
            current_sp:,
            residential_address_resolution_result:,
            state_id_address_resolution_result:,
            timer: an_instance_of(JobHelpers::Timer),
            user_email:,
            best_effort_phone: nil,
            is_proofing_agent: false,
          ).and_call_original
          proof
        end

        it 'returns a ResultAdjudicator' do
          proof.tap do |result|
            expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)
            expect(result.resolution_result).to eql(state_id_address_resolution_result)
            expect(result.device_profiling_result).to eql(threatmetrix_result)
            expect(result.residential_resolution_result).to(
              eql(residential_address_resolution_result),
            )
            expect(result.ipp_enrollment_in_progress).to eql(true)
            expect(result.ipp_current_address_matches_id).to eql(false)
          end
        end
      end
    end

    context 'when the applicant has a passport document type' do
      let(:applicant_pii) do
        { uuid: user.uuid }.merge(Idp::Constants::MOCK_IDV_PROOFING_PASSPORT_APPLICANT)
      end

      it 'calls ThreatMetrixPlugin' do
        expect(progressive_proofer.threatmetrix_plugin).to receive(:call).with(
          applicant_pii:,
          current_sp:,
          request_ip:,
          threatmetrix_session_id:,
          timer: an_instance_of(JobHelpers::Timer),
          user_email:,
          user_uuid:,
          workflow:,
          ddp_policy: threatmetrix_ddp_policy,
        )
        proof
      end

      context 'with hybrid mobile device profiling enabled' do
        let(:hybrid_device_profiling) { :enabled }
        let(:hybrid_mobile_threatmetrix_session_id) { SecureRandom.uuid }
        let(:hybrid_mobile_request_ip) { Faker::Internet.ip_v4_address }

        before do
          allow(progressive_proofer.threatmetrix_plugin).to receive(:call)
            .and_return(threatmetrix_result, hybrid_mobile_threatmetrix_result)
        end

        it 'returns a ResultAdjudicator with both device profiling results' do
          proof.tap do |result|
            expect(result.device_profiling_result).to eql(threatmetrix_result)
            expect(result.hybrid_mobile_device_profiling_result)
              .to eql(hybrid_mobile_threatmetrix_result)
          end
        end
      end

      it 'calls ResidentialAddressPlugin' do
        expect(progressive_proofer.residential_address_plugin).to receive(:call).with(
          applicant_pii:,
          current_sp:,
          ipp_enrollment_in_progress:,
          timer: an_instance_of(JobHelpers::Timer),
        ).and_call_original
        proof
      end

      it 'calls StateIdAddressPlugin' do
        expect(progressive_proofer.state_id_address_plugin).to receive(:call).with(
          applicant_pii:,
          current_sp:,
          residential_address_resolution_result: satisfy do |result|
            expect(result.success?).to eql(true)
            expect(result.vendor_name).to eql('ResidentialAddressNotRequired')
          end,
          ipp_enrollment_in_progress:,
          timer: an_instance_of(JobHelpers::Timer),
        ).and_call_original
        proof
      end

      it 'calls PhonePlugin' do
        expect(progressive_proofer.phone_plugin).to receive(:call).with(
          applicant_pii:,
          current_sp:,
          residential_address_resolution_result: satisfy do |result|
            expect(result.success?).to eql(true)
            expect(result.vendor_name).to eql('ResidentialAddressNotRequired')
          end,
          state_id_address_resolution_result:,
          timer: an_instance_of(JobHelpers::Timer),
          user_email:,
          best_effort_phone: nil,
          is_proofing_agent: false,
        ).and_call_original
        proof
      end

      it 'returns a ResultAdjudicator' do
        proof.tap do |result|
          expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)
          expect(result.resolution_result).to eql(state_id_address_resolution_result)
          expect(result.device_profiling_result).to eql(threatmetrix_result)
          expect(result.residential_resolution_result).to satisfy do |result|
            expect(result.success?).to eql(true)
            expect(result.vendor_name).to eql('ResidentialAddressNotRequired')
          end
          expect(result.phone_result[:alternate_result]).to be_nil
          expect(result.phone_result[:success]).to eq(false)
          expect(result.phone_result[:vendor_name]).to eq('NoPhoneNumberAvailable')
          expect(result.ipp_enrollment_in_progress).to eql(false)
          expect(result.ipp_current_address_matches_id).to eql(nil)
        end
      end

      context 'when phone precheck is not enabled' do
        let(:idv_phone_precheck_percent) { 0 }
        it 'returns a ResultAdjudicator' do
          proof.tap do |result|
            expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)
            expect(result.resolution_result).to eql(state_id_address_resolution_result)
            expect(result.device_profiling_result).to eql(threatmetrix_result)
            expect(result.residential_resolution_result).to satisfy do |result|
              expect(result.success?).to eql(true)
              expect(result.vendor_name).to eql('ResidentialAddressNotRequired')
            end
            expect(result.phone_result).to be_empty
            expect(result.ipp_enrollment_in_progress).to eql(false)
            expect(result.ipp_current_address_matches_id).to eql(nil)
          end
        end
      end
    end

    context 'when applicant_pii includes best_effort_phone_number_for_socure' do
      let(:applicant_pii) do
        {
          best_effort_phone_number_for_socure: { phone: '3608675309' },
          uuid: user.uuid,
        }.merge(Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN)
      end

      it 'does not pass the phone number to plugins' do
        expected_applicant_pii = applicant_pii.except(:best_effort_phone_number_for_socure)

        plugin_methods = %i[
          residential_address_plugin
          state_id_address_plugin
          threatmetrix_plugin
        ]

        plugin_methods.each do |plugin_method_name|
          plugin = progressive_proofer.send(plugin_method_name)
          expect(plugin).to receive(:call).with(
            hash_including(
              applicant_pii: expected_applicant_pii,
            ),
          ).and_call_original
        end

        expect(progressive_proofer.phone_plugin).to receive(:call).with(
          hash_including(
            applicant_pii: expected_applicant_pii,
            best_effort_phone: { phone: '3608675309' },
          ),
        ).and_call_original

        proof
      end

      it 'returns a ResultAdjudicator' do
        proof.tap do |result|
          expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)

          expect(result.resolution_result).to eql(state_id_address_resolution_result)
          expect(result.device_profiling_result).to eql(threatmetrix_result)
          expect(result.phone_result[:alternate_result]).to be_nil
          expect(result.phone_result[:success]).to eq(true)
          expect(result.phone_result[:vendor_name]).to eq('AddressMock')
          expect(result.residential_resolution_result).to satisfy do |result|
            expect(result.success?).to eql(true)
            expect(result.vendor_name).to eql('ResidentialAddressNotRequired')
          end
          expect(result.ipp_enrollment_in_progress).to eql(false)
          expect(result.ipp_current_address_matches_id).to eql(nil)
        end
      end
    end
  end

  describe '#residential_address_plugin' do
    let(:proofing_vendor) { nil }

    before do
      allow(progressive_proofer).to receive(:proofing_vendor).and_return(proofing_vendor)
    end

    context 'when proofing_vendor is :instant_verify' do
      let(:proofing_vendor) { :instant_verify }

      it 'returns ResidentialAddressPlugin with an InstantVerify proofer' do
        expect(progressive_proofer.residential_address_plugin).to be_an_instance_of(
          Proofing::Resolution::Plugins::ResidentialAddressPlugin,
        )

        expect(progressive_proofer.residential_address_plugin.proofer).to be_an_instance_of(
          Proofing::LexisNexis::InstantVerify::Proofer,
        )
      end
    end

    context 'when proofing_vendor is :instant_verify_ddp' do
      let(:proofing_vendor) { :instant_verify_ddp }

      it 'returns ResidentialAddressPlugin with an InstantVerify proofer' do
        expect(progressive_proofer.residential_address_plugin).to be_an_instance_of(
          Proofing::Resolution::Plugins::ResidentialAddressPlugin,
        )

        expect(progressive_proofer.residential_address_plugin.proofer).to be_an_instance_of(
          Proofing::LexisNexis::Ddp::Proofers::InstantVerifyProofer,
        )
      end
    end

    context 'when proofing_vendor is :mock' do
      let(:proofing_vendor) { :mock }

      it 'returns ResidentialAddressPlugin with a mock proofer' do
        expect(progressive_proofer.residential_address_plugin).to be_an_instance_of(
          Proofing::Resolution::Plugins::ResidentialAddressPlugin,
        )

        expect(progressive_proofer.residential_address_plugin.proofer).to be_an_instance_of(
          Proofing::Mock::ResolutionMockClient,
        )
      end
    end

    context 'when proofing_vendor is :socure_kyc' do
      let(:proofing_vendor) { :socure_kyc }

      it 'returns ResidentialAddressPlugin with a Socure proofer' do
        expect(progressive_proofer.residential_address_plugin).to be_an_instance_of(
          Proofing::Resolution::Plugins::ResidentialAddressPlugin,
        )

        expect(progressive_proofer.residential_address_plugin.proofer).to be_an_instance_of(
          Proofing::Socure::IdPlus::Proofers::KycProofer,
        )
      end
    end

    context 'when proofing_vendor is another value' do
      let(:proofing_vendor) { :a_dog }

      it 'raises an error' do
        expect { progressive_proofer.residential_address_plugin }.to raise_error
      end
    end
  end

  describe '#state_id_address_plugin' do
    let(:proofing_vendor) { nil }

    before do
      allow(progressive_proofer).to receive(:proofing_vendor).and_return(proofing_vendor)
    end

    context 'when proofing_vendor is :instant_verify' do
      let(:proofing_vendor) { :instant_verify }

      it 'returns StateIdAddressPlugin with an InstantVerify proofer' do
        expect(progressive_proofer.state_id_address_plugin).to be_an_instance_of(
          Proofing::Resolution::Plugins::StateIdAddressPlugin,
        )

        expect(progressive_proofer.state_id_address_plugin.proofer).to be_an_instance_of(
          Proofing::LexisNexis::InstantVerify::Proofer,
        )
      end
    end

    context 'when proofing_vendor is :instant_verify_ddp' do
      let(:proofing_vendor) { :instant_verify_ddp }

      it 'returns StateIdAddressPlugin with an InstantVerify proofer' do
        expect(progressive_proofer.state_id_address_plugin).to be_an_instance_of(
          Proofing::Resolution::Plugins::StateIdAddressPlugin,
        )

        expect(progressive_proofer.state_id_address_plugin.proofer).to be_an_instance_of(
          Proofing::LexisNexis::Ddp::Proofers::InstantVerifyProofer,
        )
      end
    end

    context 'when proofing_vendor is :socure_kyc' do
      let(:proofing_vendor) { :socure_kyc }

      it 'returns StateIdAddressPlugin with a Socure proofer' do
        expect(progressive_proofer.state_id_address_plugin).to be_an_instance_of(
          Proofing::Resolution::Plugins::StateIdAddressPlugin,
        )

        expect(progressive_proofer.state_id_address_plugin.proofer).to be_an_instance_of(
          Proofing::Socure::IdPlus::Proofers::KycProofer,
        )
      end
    end

    context 'when proofing_vendor is :mock' do
      let(:proofing_vendor) { :mock }

      it 'returns StateIdAddressPlugin with a mock proofer' do
        expect(progressive_proofer.state_id_address_plugin).to be_an_instance_of(
          Proofing::Resolution::Plugins::StateIdAddressPlugin,
        )

        expect(progressive_proofer.state_id_address_plugin.proofer).to be_an_instance_of(
          Proofing::Mock::ResolutionMockClient,
        )
      end
    end

    context 'when proofing_vendor is another value' do
      let(:proofing_vendor) { :🦨 }

      it 'raises an error' do
        expect { progressive_proofer.state_id_address_plugin }.to raise_error
      end
    end
  end
end
