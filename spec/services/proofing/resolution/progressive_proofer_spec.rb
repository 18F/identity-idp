require 'rails_helper'

RSpec.describe Proofing::Resolution::ProgressiveProofer do
  let(:user) { build(:user) }
  let(:user_uuid) { user.uuid }
  let(:user_email) { user.email }
  let(:proofing_vendor) { :mock }

  subject(:progressive_proofer) { described_class.new(user_uuid:, proofing_vendor:, user_email:) }

  it 'assigns aamva_plugin' do
    expect(
      described_class.new(user_uuid:, proofing_vendor:, user_email:).aamva_plugin,
    ).to be_a(
      Proofing::Resolution::Plugins::AamvaPlugin,
    )
  end

  it 'assigns threatmetrix_plugin' do
    expect(
      described_class.new(user_uuid:, proofing_vendor:, user_email:).threatmetrix_plugin,
    ).to be_a(
      Proofing::Resolution::Plugins::ThreatMetrixPlugin,
    )
  end

  describe '#proof' do
    let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE }
    let(:ipp_enrollment_in_progress) { false }
    let(:request_ip) { Faker::Internet.ip_v4_address }
    let(:threatmetrix_session_id) { SecureRandom.uuid }
    let(:current_sp) { build(:service_provider) }
    let(:workflow) { :auth }

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
      # In cases where both calls are made, the residential call is made
      # before the state id address call
      [residential_address_resolution_result, state_id_address_resolution_result]
    end

    let(:resolution_proofer) do
      instance_double(
        Proofing::LexisNexis::InstantVerify::Proofer,
      )
    end

    let(:aamva_result) do
      Proofing::StateIdResult.new(
        success: true,
        transaction_id: 'aamva-123',
      )
    end

    let(:aamva_proofer) { instance_double(Proofing::Aamva::Proofer, proof: aamva_result) }

    let(:threatmetrix_result) do
      Proofing::DdpResult.new(
        success: true,
        transaction_id: 'ddp-123',
      )
    end

    let(:threatmetrix_proofer) do
      instance_double(
        Proofing::LexisNexis::Ddp::Proofer,
        proof: threatmetrix_result,
      )
    end

    let(:phone_finder_result) do
      Proofing::Resolution::Result.new(
        success: false, vendor_name: 'NoPhoneNumberAvailable',
      )
    end

    let(:phone_finder_proofer) do
      instance_double(
        Proofing::LexisNexis::PhoneFinder::Proofer,
        proof: phone_finder_result,
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
      )
    end

    before do
      allow(resolution_proofer).to receive(:proof).and_return(*resolution_proofing_results)
      allow(progressive_proofer).to receive(:create_proofer)
        .and_return(resolution_proofer)

      allow(progressive_proofer.threatmetrix_plugin).to receive(:proofer)
        .and_return(threatmetrix_proofer)

      allow(progressive_proofer.aamva_plugin).to receive(:proofer)
        .and_return(aamva_proofer)
      allow(progressive_proofer.phone_finder_plugin).to receive(:proofer)
        .and_return(phone_finder_proofer)
    end

    context 'remote unsupervised proofing' do
      let(:resolution_proofing_results) do
        # No call is made for residential address on remote unsupervised path
        [state_id_address_resolution_result]
      end

      it 'calls AamvaPlugin' do
        expect(progressive_proofer.aamva_plugin).to receive(:call).with(
          applicant_pii:,
          current_sp:,
          state_id_address_resolution_result:,
          ipp_enrollment_in_progress: false,
          timer: an_instance_of(JobHelpers::Timer),
        ).and_call_original
        proof
      end

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
        )
        proof
      end

      it 'returns a ResultAdjudicator' do
        proof.tap do |result|
          expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)

          expect(result.resolution_result).to eql(state_id_address_resolution_result)
          expect(result.state_id_result).to eql(aamva_result)
          expect(result.device_profiling_result).to eql(threatmetrix_result)
          expect(result.phone_finder_result).to eq(phone_finder_result)
          expect(result.residential_resolution_result).to satisfy do |result|
            expect(result.success?).to eql(true)
            expect(result.vendor_name).to eql('ResidentialAddressNotRequired')
          end
          expect(result.ipp_enrollment_in_progress).to eql(false)
          expect(result.same_address_as_id).to eql(nil)
        end
      end
    end

    context 'in-person proofing' do
      let(:ipp_enrollment_in_progress) { true }

      context 'residential address is same as id' do
        let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID }

        let(:state_id_address_resolution_result) do
          residential_address_resolution_result
        end

        it 'calls AamvaPlugin' do
          expect(progressive_proofer.aamva_plugin).to receive(:call).with(
            applicant_pii:,
            current_sp:,
            state_id_address_resolution_result:,
            ipp_enrollment_in_progress: true,
            timer: an_instance_of(JobHelpers::Timer),
          )

          proof
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
          )
          proof
        end

        it 'calls PhoneFinderPlugin' do
          expect(progressive_proofer.phone_finder_plugin).to receive(:call).with(
            applicant_pii:,
            current_sp:,
            residential_address_resolution_result:,
            state_id_address_resolution_result:,
            state_id_result: aamva_result,
            ipp_enrollment_in_progress: true,
            timer: an_instance_of(JobHelpers::Timer),
          ).and_call_original
          proof
        end

        it 'returns a ResultAdjudicator' do
          proof.tap do |result|
            expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)

            expect(result.resolution_result).to eql(state_id_address_resolution_result)
            expect(result.state_id_result).to eql(aamva_result)
            expect(result.device_profiling_result).to eql(threatmetrix_result)
            expect(result.phone_finder_result).to satisfy do |phone_finder_result|
              expect(phone_finder_result.success?).to eq(false)
              expect(phone_finder_result.vendor_name).to eq('PhoneIgnoredForInPersonProofing')
            end
            expect(result.residential_resolution_result).to(
              eql(state_id_address_resolution_result),
            )
            expect(result.ipp_enrollment_in_progress).to eql(true)
            expect(proof.same_address_as_id).to eq(applicant_pii[:same_address_as_id])
          end
        end
      end

      context 'residential address is different than id' do
        let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS }

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
          )
          proof
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

        it 'calls AamvaPlugin' do
          expect(progressive_proofer.aamva_plugin).to receive(:call).with(
            applicant_pii:,
            current_sp:,
            state_id_address_resolution_result:,
            ipp_enrollment_in_progress: true,
            timer: an_instance_of(JobHelpers::Timer),
          ).and_call_original
          proof
        end

        it 'calls PhoneFinderPlugin' do
          expect(progressive_proofer.phone_finder_plugin).to receive(:call).with(
            applicant_pii:,
            current_sp:,
            residential_address_resolution_result:,
            state_id_address_resolution_result:,
            state_id_result: aamva_result,
            ipp_enrollment_in_progress: true,
            timer: an_instance_of(JobHelpers::Timer),
          ).and_call_original
          proof
        end

        it 'returns a ResultAdjudicator' do
          proof.tap do |result|
            expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)
            expect(result.resolution_result).to eql(state_id_address_resolution_result)
            expect(result.state_id_result).to eql(aamva_result)
            expect(result.device_profiling_result).to eql(threatmetrix_result)
            expect(result.residential_resolution_result).to(
              eql(residential_address_resolution_result),
            )
            expect(result.ipp_enrollment_in_progress).to eql(true)
            expect(result.same_address_as_id).to eql('false')
          end
        end
      end
    end

    context 'when applicant_pii includes best_effort_phone_number_for_socure' do
      let(:applicant_pii) do
        Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.merge(
          best_effort_phone_number_for_socure: '3608675309',
        )
      end

      it 'does not pass the phone number to plugins' do
        expected_applicant_pii = applicant_pii.except(:best_effort_phone_number_for_socure)

        plugin_methods = %i[
          aamva_plugin
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

        proof
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
          Proofing::Socure::IdPlus::Proofer,
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

    context 'when proofing_vendor is :socure_kyc' do
      let(:proofing_vendor) { :socure_kyc }

      it 'returns StateIdAddressPlugin with a Socure proofer' do
        expect(progressive_proofer.state_id_address_plugin).to be_an_instance_of(
          Proofing::Resolution::Plugins::StateIdAddressPlugin,
        )

        expect(progressive_proofer.state_id_address_plugin.proofer).to be_an_instance_of(
          Proofing::Socure::IdPlus::Proofer,
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
