require 'rails_helper'

RSpec.describe Proofing::Resolution::ProgressiveProofer do
  let(:user) { build(:user) }
  let(:primary_vendor) { :socure_kyc }
  let(:fallback_vendor) { :instant_verify_ddp }
  let(:enabled) { true }
  let(:is_proofing_agent) { false }
  let(:ipp_enrollment_in_progress) { false }
  let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE.merge(uuid: user.uuid) }
  let(:timer) { JobHelpers::Timer.new }
  let(:current_sp) { build(:service_provider) }
  let(:device_result) { Proofing::DdpResult.new(success: true, review_status: 'pass') }
  let(:primary_result) do
    Proofing::Resolution::Result.new(
      success: false, vendor_name: primary_vendor.to_s, transaction_id: 'primary-tx',
    )
  end
  let(:fallback_result) do
    Proofing::Resolution::Result.new(
      success: true, vendor_name: fallback_vendor.to_s, transaction_id: 'fallback-tx',
    )
  end
  let(:primary_proofer) { instance_double(Proofing::Socure::IdPlus::Proofers::KycProofer) }
  let(:fallback_proofer) do
    instance_double(Proofing::LexisNexis::Ddp::Proofers::InstantVerifyProofer)
  end
  let(:proofer) do
    described_class.new(
      user_uuid: user.uuid, user_email: user.email, analytics: FakeAnalytics.new,
      proofing_vendor: primary_vendor, is_proofing_agent:
    )
  end

  subject(:proof) do
    proofer.proof(
      applicant_pii:, current_sp:, timer:, ipp_enrollment_in_progress:,
      request_ip: nil, threatmetrix_session_id: nil, workflow: :idv
    )
  end

  before do
    allow(IdentityConfig.store).to receive_messages(
      idv_resolution_failover_enabled: enabled,
      idv_resolution_vendor_switching_enabled: true,
      idv_resolution_vendor_socure_kyc_percent: 60,
      idv_resolution_vendor_instant_verify_ddp_percent: 40,
      idv_resolution_vendor_instant_verify_percent: 0,
      idv_resolution_default_vendor: :mock,
      idv_aamva_get_to_yes_enabled_vendors: [],
    )
    reload_ab_tests
    allow(proofer.threatmetrix_plugin).to receive(:call).and_return(device_result)
    allow(proofer.phone_plugin).to receive(:call).and_return({})
    allow(proofer).to receive(:create_proofer).with(primary_vendor).and_return(primary_proofer)
    allow(proofer).to receive(:create_proofer).with(fallback_vendor).and_return(fallback_proofer)
    allow(primary_proofer).to receive(:proof).and_return(primary_result)
    allow(fallback_proofer).to receive(:proof).and_return(fallback_result)
  end

  it 'fails over, attributes the selected result, and records both costs and timings' do
    expect(primary_proofer).to receive(:proof).with(applicant_pii)
      .ordered.and_return(primary_result)
    expect(fallback_proofer).to receive(:proof).with(applicant_pii)
      .ordered.and_return(fallback_result)
    expect(Db::SpCost::AddSpCost).to receive(:call)
      .with(current_sp, :socure_resolution, transaction_id: 'primary-tx')
    expect(Db::SpCost::AddSpCost).to receive(:call)
      .with(current_sp, :lexis_nexis_resolution, transaction_id: 'fallback-tx')
    expect(proofer.threatmetrix_plugin).to receive(:call).once
    expect(proofer.phone_plugin).to receive(:call).once.with(
      hash_including(state_id_address_resolution_result: fallback_result),
    )

    expect(proof.adjudicated_result.success?).to eq(true)
    expect(proof.proofing_vendor).to eq(fallback_vendor)
    expect(proof.resolution_result).to equal(fallback_result)
    expect(proof.resolution_attempts.map { |attempt| attempt[:vendor] })
      .to eq([primary_vendor, fallback_vendor])
    expect(timer.results.keys).to contain_exactly(
      'resolution socure_kyc', 'resolution instant_verify_ddp'
    )
  end

  context 'with LexisNexis assigned first' do
    let(:primary_vendor) { :instant_verify_ddp }
    let(:fallback_vendor) { :socure_kyc }

    it 'fails over to Socure' do
      expect(proof.resolution_success?).to eq(true)
      expect(proof.proofing_vendor).to eq(:socure_kyc)
    end
  end

  context 'with failover disabled' do
    let(:enabled) { false }

    it 'preserves the single-provider failure, result shape, and timer keys' do
      expect(fallback_proofer).not_to receive(:proof)
      expect(proof.resolution_result).to equal(primary_result)
      expect(proof.adjudicated_result.success?).to eq(false)
      expect(proof.adjudicated_result.extra[:context]).not_to have_key(:resolution_attempts)
      expect(timer.results.keys).to eq(['resolution'])
    end
  end

  [false, true].each do |failover_enabled|
    context "with failover_enabled=#{failover_enabled} and an unhandled exception" do
      let(:enabled) { failover_enabled }

      it 'propagates the exception without attempting another provider' do
        allow(primary_proofer).to receive(:proof).and_raise(JSON::ParserError, 'invalid response')
        expect(fallback_proofer).not_to receive(:proof)
        expect { proof }.to raise_error(JSON::ParserError, 'invalid response')
      end
    end
  end

  context 'when the primary succeeds' do
    let(:primary_result) { Proofing::Resolution::Result.new(success: true) }

    it 'does not call a fallback' do
      expect(fallback_proofer).not_to receive(:proof)
      expect(proof.resolution_success?).to eq(true)
    end

    context 'when device profiling has an exception' do
      let(:device_result) do
        Proofing::DdpResult.new(success: false, exception: Proofing::TimeoutError.new)
      end

      it 'does not fail over because resolution already passed' do
        expect(fallback_proofer).not_to receive(:proof)
        expect(proof.resolution_success?).to eq(true)
        expect(proof.adjudicated_result.success?).to eq(false)
      end
    end
  end

  [
    Proofing::TimeoutError.new,
    Proofing::Socure::IdPlus::Request::Error.new(StandardError.new),
  ].each do |error|
    context "with a normalized #{error.class} result" do
      let(:primary_result) { Proofing::Resolution::Result.new(success: false, exception: error) }

      it 'tries the fallback and keeps the failure classification in attempt history' do
        expect(proof.resolution_success?).to eq(true)
        expect(proof.resolution_attempts.first[:resolution][:exception_class])
          .to eq(error.class.name)
        expect(proof.adjudicated_result.extra[:exception]).to be_nil
      end
    end
  end

  context 'when all providers fail' do
    let(:fallback_result) { Proofing::Resolution::Result.new(success: false) }

    it 'uses the last failure and retains both attempts' do
      expect(proof.resolution_success?).to eq(false)
      expect(proof.resolution_result).to equal(fallback_result)
      expect(proof.resolution_attempts.size).to eq(2)
    end
  end

  context 'with AAMVA-verified attributes' do
    let(:applicant_pii) { super().merge(aamva_verified_attributes: [:address]) }
    let(:primary_result) do
      Proofing::Resolution::Result.new(
        success: false, failed_result_can_pass_with_additional_verification: true,
        attributes_requiring_additional_verification: [:address]
      )
    end

    before do
      allow(IdentityConfig.store).to receive(:idv_aamva_get_to_yes_enabled_vendors)
        .and_return([primary_vendor.to_s])
    end

    it 'stops on an AAMVA-rescued primary result' do
      expect(fallback_proofer).not_to receive(:proof)
      expect(proof.resolution_success?).to eq(true)
      expect(proof.resolution_result).to equal(primary_result)
    end

    context 'when the address was edited' do
      let(:applicant_pii) { super().merge(address_edited: true) }

      it 'fails over because AAMVA cannot cover the edited address' do
        expect(proof.proofing_vendor).to eq(fallback_vendor)
      end
    end

    context 'when only the fallback vendor is enabled for get-to-yes' do
      let(:fallback_result) { primary_result }

      before do
        allow(IdentityConfig.store).to receive(:idv_aamva_get_to_yes_enabled_vendors)
          .and_return([fallback_vendor.to_s])
      end

      it 'uses the fallback vendor rules and stops on its AAMVA-rescued result' do
        expect(proof.resolution_success?).to eq(true)
        expect(proof.proofing_vendor).to eq(fallback_vendor)
        expect(proof.resolution_attempts.map { |attempt| attempt[:success] }).to eq([false, true])
      end
    end
  end

  context 'in-person proofing with different addresses' do
    let(:ipp_enrollment_in_progress) { true }
    let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS.merge(uuid: user.uuid) }

    it 'restarts both addresses using separate fallback clients' do
      residential_proofer = instance_double(Proofing::Socure::IdPlus::Proofers::KycProofer)
      state_id_proofer = instance_double(Proofing::Socure::IdPlus::Proofers::KycProofer)
      allow(proofer).to receive(:create_proofer).with(fallback_vendor)
        .and_return(residential_proofer, state_id_proofer)
      expect(primary_proofer).to receive(:proof).once.with(applicant_pii).and_return(primary_result)
      expect(residential_proofer).to receive(:proof).with(applicant_pii)
        .ordered.and_return(fallback_result)
      expect(state_id_proofer).to receive(:proof).with(
        hash_including(address1: applicant_pii[:identity_doc_address1]),
      ).ordered.and_return(fallback_result)
      expect(proof.resolution_success?).to eq(true)
      expect(proof.residential_resolution_result).to equal(fallback_result)
    end

    context 'when the primary residential address passed but the document address failed' do
      before do
        allow(primary_proofer).to receive(:proof).and_return(fallback_result, primary_result)
      end

      it 'repeats both addresses with the fallback vendor' do
        expect(fallback_proofer).to receive(:proof).twice.and_return(fallback_result)
        expect(proof.proofing_vendor).to eq(fallback_vendor)
      end
    end

    context 'with matching addresses' do
      let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID.merge(uuid: user.uuid) }

      it 'makes one provider request per attempt and reuses the residential result' do
        expect(primary_proofer).to receive(:proof).once.and_return(primary_result)
        expect(fallback_proofer).to receive(:proof).once.and_return(fallback_result)
        expect(proof.resolution_result).to equal(proof.residential_resolution_result)
        expect(proof.resolution_success?).to eq(true)
      end
    end
  end

  describe 'vendor eligibility and ordering' do
    it 'includes each positive-share provider once with the assigned provider first' do
      expect(proofer.resolution_vendors).to eq([:socure_kyc, :instant_verify_ddp])
    end

    it 'includes the default vendor residual share in descending traffic order' do
      allow(IdentityConfig.store).to receive_messages(
        idv_resolution_vendor_socure_kyc_percent: 10,
        idv_resolution_vendor_instant_verify_ddp_percent: 20,
        idv_resolution_default_vendor: :instant_verify,
      )
      reload_ab_tests
      expect(proofer.resolution_vendors).to eq([:socure_kyc, :instant_verify, :instant_verify_ddp])
    end

    it 'adds residual traffic to the default vendor explicit share' do
      allow(IdentityConfig.store).to receive_messages(
        idv_resolution_vendor_socure_kyc_percent: 10,
        idv_resolution_vendor_instant_verify_ddp_percent: 40,
        idv_resolution_vendor_instant_verify_percent: 20,
        idv_resolution_default_vendor: :instant_verify,
      )
      reload_ab_tests
      expect(proofer.resolution_vendors).to eq([:socure_kyc, :instant_verify, :instant_verify_ddp])
    end

    it 'breaks equal-share ties using bucket order' do
      allow(IdentityConfig.store).to receive_messages(
        idv_resolution_vendor_socure_kyc_percent: 20,
        idv_resolution_vendor_instant_verify_percent: 40,
      )
      reload_ab_tests
      expect(proofer.resolution_vendors).to eq([:socure_kyc, :instant_verify, :instant_verify_ddp])
    end

    it 'excludes zero-share providers and mock default traffic' do
      allow(IdentityConfig.store).to receive(:idv_resolution_vendor_instant_verify_ddp_percent)
        .and_return(0)
      reload_ab_tests
      expect(fallback_proofer).not_to receive(:proof)
      expect(proof.resolution_success?).to eq(false)
      expect(proof.resolution_attempts.size).to eq(1)
    end

    it 'respects disabled vendor switching even when configured percentages are positive' do
      allow(IdentityConfig.store).to receive_messages(
        idv_resolution_vendor_switching_enabled: false,
        idv_resolution_default_vendor: primary_vendor,
      )
      reload_ab_tests
      expect(proofer.resolution_vendors).to eq([primary_vendor])
    end

    it 'tries three eligible vendors at most once and stops on the first adjudicated success' do
      allow(IdentityConfig.store).to receive_messages(
        idv_resolution_vendor_socure_kyc_percent: 10,
        idv_resolution_vendor_instant_verify_percent: 50,
      )
      reload_ab_tests
      third_proofer = instance_double(Proofing::LexisNexis::InstantVerify::Proofer)
      allow(proofer).to receive(:create_proofer).with(:instant_verify).and_return(third_proofer)
      expect(primary_proofer).to receive(:proof).ordered.and_return(primary_result)
      expect(third_proofer).to receive(:proof).ordered.and_return(primary_result)
      expect(fallback_proofer).to receive(:proof).ordered.and_return(fallback_result)
      expect(proof.resolution_attempts.map { |attempt| attempt[:vendor] })
        .to eq([:socure_kyc, :instant_verify, :instant_verify_ddp])
    end

    context 'for proofing agents' do
      let(:is_proofing_agent) { true }

      it 'uses the proofing-agent routing configuration and returns the fallback result' do
        expect(proof.proofing_vendor).to eq(fallback_vendor)
        expect(proof.resolution_success?).to eq(true)
      end
    end
  end
end
