require 'rails_helper'

RSpec.describe Proofing::Resolution::ProgressiveProofer do
  let(:user) { build(:user) }
  let(:user_uuid) { user.uuid }
  let(:user_email) { user.email }
  let(:proofing_vendor) { :mock }
  let(:idv_phone_precheck_percent) { 100 }
  let(:analytics) { FakeAnalytics.new }

  subject(:progressive_proofer) do
    described_class.new(user_uuid:, proofing_vendor:, analytics:, user_email:)
  end

  it 'assigns aamva_plugin' do
    expect(
      progressive_proofer.aamva_plugin,
    ).to be_a(
      Proofing::Resolution::Plugins::AamvaPlugin,
    )
  end

  it 'assigns threatmetrix_plugin' do
    expect(
      progressive_proofer.threatmetrix_plugin,
    ).to be_a(
      Proofing::Resolution::Plugins::ThreatMetrixPlugin,
    )
  end

  describe '#proof' do
    let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE.dup }
    let(:ipp_enrollment_in_progress) { false }
    let(:state_id_already_proofed) { false }
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
      # No call is made for residential address on remote unsupervised path
      [state_id_address_resolution_result]
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

    subject(:proof) do
      progressive_proofer.proof(
        applicant_pii:,
        ipp_enrollment_in_progress:,
        request_ip:,
        threatmetrix_session_id:,
        timer: JobHelpers::Timer.new,
        current_sp:,
        workflow:,
        state_id_already_proofed:,
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
      allow(IdentityConfig.store).to receive(:idv_phone_precheck_percent)
        .and_return(idv_phone_precheck_percent)
    end

    context 'remote unsupervised proofing' do
      it 'calls AamvaPlugin' do
        expect(progressive_proofer.aamva_plugin).to receive(:call).with(
          applicant_pii:,
          current_sp:,
          state_id_address_resolution_result:,
          ipp_enrollment_in_progress: false,
          timer: an_instance_of(JobHelpers::Timer),
          already_proofed: false,
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
          expect(result.phone_result[:alternate_result]).to be_nil
          expect(result.phone_result[:success]).to eq(true)
          expect(result.phone_result[:vendor_name]).to eq('AddressMock')
          expect(result.residential_resolution_result).to satisfy do |result|
            expect(result.success?).to eql(true)
            expect(result.vendor_name).to eql('ResidentialAddressNotRequired')
          end
          expect(result.ipp_enrollment_in_progress).to eql(false)
          expect(result.same_address_as_id).to eql(nil)
        end
      end

      context 'when aamva fails' do
        before do
          allow(aamva_proofer).to receive(:proof).and_return(
            Proofing::StateIdResult.new(
              success: false,
              transaction_id: 'aamva-failed-123',
            ),
          )
        end

        it 'phone precheck auto fails' do
          expect(Proofing::AddressProofer).not_to receive(:new)

          proof.tap do |result|
            expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)

            expect(result.resolution_result.success?).to be_truthy
            expect(result.state_id_result.success?).to be_falsey
            expect(result.state_id_result.transaction_id).to eq('aamva-failed-123')
            expect(result.device_profiling_result).to eql(threatmetrix_result)
            expect(result.phone_result[:alternate_result]).to be_nil
            expect(result.phone_result[:success]).to be_falsey
            expect(result.phone_result[:vendor_name]).to eq('ResolutionCannotPass')
          end
        end
      end

      context 'when state_id address resolution fails' do
        let(:state_id_address_resolution_result) do
          Proofing::Resolution::Result.new(
            success: false,
            transaction_id: 'state-id-resolution-failed-tx',
          )
        end
        it 'phone precheck auto fails and aamva is not called' do
          expect(Proofing::AddressProofer).not_to receive(:new)

          proof.tap do |result|
            expect(result.resolution_result.success?).to be_falsey
            expect(result.state_id_result.success?).to be_truthy
            expect(result.state_id_result.vendor_name).to eq('UnsupportedJurisdiction')
            expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)
            expect(result.phone_result[:alternate_result]).to be_nil
            expect(result.phone_result[:success]).to be_falsey
            expect(result.phone_result[:vendor_name]).to eq('ResolutionCannotPass')
          end
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
            expect(result.state_id_result).to eql(aamva_result)
            expect(result.device_profiling_result.success?).to be_falsey
            expect(result.device_profiling_result.transaction_id).to eq('ddp-failed-123')
            expect(result.phone_result[:alternate_result]).to be_nil
            expect(result.phone_result[:success]).to eq(true)
            expect(result.phone_result[:vendor_name]).to eq('AddressMock')
          end
        end
      end

      context 'when precheck is not enabled' do
        let(:idv_phone_precheck_percent) { 0 }
        it 'returns a ResultAdjudicator' do
          proof.tap do |result|
            expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)

            expect(result.resolution_result).to eql(state_id_address_resolution_result)
            expect(result.state_id_result).to eql(aamva_result)
            expect(result.device_profiling_result).to eql(threatmetrix_result)
            expect(result.phone_result).to be_empty
            expect(result.residential_resolution_result).to satisfy do |result|
              expect(result.success?).to eql(true)
              expect(result.vendor_name).to eql('ResidentialAddressNotRequired')
            end
            expect(result.ipp_enrollment_in_progress).to eql(false)
            expect(result.same_address_as_id).to eql(nil)
          end
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
        let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID.dup }

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
            already_proofed: false,
          ).and_call_original

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

        it 'calls PhonePlugin' do
          expect(progressive_proofer.phone_plugin).to receive(:call).with(
            applicant_pii:,
            current_sp:,
            residential_address_resolution_result:,
            state_id_address_resolution_result:,
            state_id_result: aamva_result,
            timer: an_instance_of(JobHelpers::Timer),
            best_effort_phone: nil,
            user_email:,
          ).and_call_original
          proof
        end

        it 'returns a ResultAdjudicator' do
          proof.tap do |result|
            expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)

            expect(result.resolution_result).to eql(state_id_address_resolution_result)
            expect(result.state_id_result).to eql(aamva_result)
            expect(result.device_profiling_result).to eql(threatmetrix_result)
            expect(result.phone_result[:alternate_result]).to be_nil
            expect(result.phone_result[:success]).to be_falsey
            expect(result.phone_result[:vendor_name]).to eq('NoPhoneNumberAvailable')
            expect(result.residential_resolution_result).to(
              eql(state_id_address_resolution_result),
            )
            expect(result.ipp_enrollment_in_progress).to eql(true)
            expect(proof.same_address_as_id).to eq(applicant_pii[:same_address_as_id])
          end
        end

        context 'when phone precheck is not enabled' do
          let(:idv_phone_precheck_percent) { 0 }
          it 'returns a ResultAdjudicator' do
            proof.tap do |result|
              expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)

              expect(result.resolution_result).to eql(state_id_address_resolution_result)
              expect(result.state_id_result).to eql(aamva_result)
              expect(result.device_profiling_result).to eql(threatmetrix_result)
              expect(result.phone_result).to be_empty
              expect(result.residential_resolution_result).to(
                eql(state_id_address_resolution_result),
              )
              expect(result.ipp_enrollment_in_progress).to eql(true)
              expect(proof.same_address_as_id).to eq(applicant_pii[:same_address_as_id])
            end
          end
        end
      end

      context 'residential address is different than id' do
        let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS.dup }

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
            already_proofed: false,
          ).and_call_original
          proof
        end

        it 'calls PhonePlugin' do
          expect(progressive_proofer.phone_plugin).to receive(:call).with(
            applicant_pii:,
            current_sp:,
            residential_address_resolution_result:,
            state_id_address_resolution_result:,
            state_id_result: aamva_result,
            timer: an_instance_of(JobHelpers::Timer),
            user_email:,
            best_effort_phone: nil,
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

    context 'when the applicant has a passport document type' do
      let(:applicant_pii) { Idp::Constants::MOCK_IDV_PROOFING_PASSPORT_APPLICANT.dup }

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

      it 'calls AamvaPlugin' do
        expect(progressive_proofer.aamva_plugin).to receive(:call).and_call_original
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
          state_id_result: satisfy do |result|
            expect(result.success?).to eql(true)
            expect(result.vendor_name).to eql(Idp::Constants::Vendors::AAMVA_CHECK_SKIPPED)
          end,
          timer: an_instance_of(JobHelpers::Timer),
          user_email:,
          best_effort_phone: nil,
        ).and_call_original
        proof
      end

      it 'returns a ResultAdjudicator' do
        proof.tap do |result|
          expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)
          expect(result.resolution_result).to eql(state_id_address_resolution_result)
          expect(result.state_id_result).to satisfy do |result|
            expect(result.success?).to eql(true)
            expect(result.vendor_name).to eql(Idp::Constants::Vendors::AAMVA_CHECK_SKIPPED)
          end
          expect(result.device_profiling_result).to eql(threatmetrix_result)
          expect(result.residential_resolution_result).to satisfy do |result|
            expect(result.success?).to eql(true)
            expect(result.vendor_name).to eql('ResidentialAddressNotRequired')
          end
          expect(result.phone_result[:alternate_result]).to be_nil
          expect(result.phone_result[:success]).to eq(false)
          expect(result.phone_result[:vendor_name]).to eq('NoPhoneNumberAvailable')
          expect(result.ipp_enrollment_in_progress).to eql(false)
          expect(result.same_address_as_id).to eql(nil)
        end
      end

      context 'when phone precheck is not enabled' do
        let(:idv_phone_precheck_percent) { 0 }
        it 'returns a ResultAdjudicator' do
          proof.tap do |result|
            expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)
            expect(result.resolution_result).to eql(state_id_address_resolution_result)
            expect(result.state_id_result).to satisfy do |result|
              expect(result.success?).to eql(true)
              expect(result.vendor_name).to eql(Idp::Constants::Vendors::AAMVA_CHECK_SKIPPED)
            end
            expect(result.device_profiling_result).to eql(threatmetrix_result)
            expect(result.residential_resolution_result).to satisfy do |result|
              expect(result.success?).to eql(true)
              expect(result.vendor_name).to eql('ResidentialAddressNotRequired')
            end
            expect(result.phone_result).to be_empty
            expect(result.ipp_enrollment_in_progress).to eql(false)
            expect(result.same_address_as_id).to eql(nil)
          end
        end
      end
    end

    context 'when idv_aamva_at_doc_auth_enabled is true' do
      let(:state_id_address_resolution_result) do
        residential_address_resolution_result
      end
      let(:state_id_already_proofed) { true }

      it 'passes already_proofed: true to AamvaPlugin' do
        expect(progressive_proofer.aamva_plugin).to receive(:call).with(
          applicant_pii:,
          current_sp:,
          state_id_address_resolution_result:,
          ipp_enrollment_in_progress:,
          timer: an_instance_of(JobHelpers::Timer),
          already_proofed: true,
        ).and_call_original
        proof
      end
    end

    context 'when applicant_pii includes best_effort_phone_number_for_socure' do
      let(:applicant_pii) do
        Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.dup.merge(
          best_effort_phone_number_for_socure: { phone: '3608675309' },
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
          expect(result.state_id_result).to eql(aamva_result)
          expect(result.device_profiling_result).to eql(threatmetrix_result)
          expect(result.phone_result[:alternate_result]).to be_nil
          expect(result.phone_result[:success]).to eq(true)
          expect(result.phone_result[:vendor_name]).to eq('AddressMock')
          expect(result.residential_resolution_result).to satisfy do |result|
            expect(result.success?).to eql(true)
            expect(result.vendor_name).to eql('ResidentialAddressNotRequired')
          end
          expect(result.ipp_enrollment_in_progress).to eql(false)
          expect(result.same_address_as_id).to eql(nil)
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
