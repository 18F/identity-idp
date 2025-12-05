require 'rails_helper'

RSpec.describe Proofing::Resolution::Plugins::AamvaPlugin do
  let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN }
  let(:already_proofed) { false }
  let(:current_sp) { build(:service_provider) }
  let(:state_id_address_resolution_result) { nil }
  let(:ipp_enrollment_in_progress) { false }
  let(:proofer) { instance_double(Proofing::Aamva::Proofer, proof: proofer_result) }
  let(:proofer_result) do
    Proofing::StateIdResult.new(
      success: true,
      vendor_name: 'state_id:aamva',
      transaction_id: proofer_transaction_id,
    )
  end
  let(:proofer_transaction_id) { 'abcd-123' }

  subject(:plugin) do
    described_class.new
  end

  before do
    allow(plugin).to receive(:proofer).and_return(proofer)
  end

  describe '#call' do
    def sp_cost_count_for_issuer
      SpCost.where(cost_type: :aamva, issuer: current_sp.issuer).count
    end

    def sp_cost_count_with_transaction_id
      SpCost.where(
        cost_type: :aamva,
        issuer: current_sp.issuer,
        transaction_id: proofer_transaction_id,
      ).count
    end

    subject(:call) do
      plugin.call(
        applicant_pii:,
        current_sp:,
        state_id_address_resolution_result:,
        ipp_enrollment_in_progress:,
        timer: JobHelpers::Timer.new,
        already_proofed:,
      )
    end

    context 'unsupervised remote proofing' do
      let(:ipp_enrollment_in_progress) { false }
      let(:state_id_address) do
        {
          address1: applicant_pii[:address1],
          address2: applicant_pii[:address2],
          city: applicant_pii[:city],
          state: applicant_pii[:state],
          state_id_jurisdiction: applicant_pii[:state_id_jurisdiction],
          zipcode: applicant_pii[:zipcode],
        }
      end

      context 'InstantVerify succeeded' do
        let(:state_id_address_resolution_result) do
          Proofing::Resolution::Result.new(
            success: true,
            vendor_name: 'lexisnexis:instant_verify',
          )
        end

        it 'calls the AAMVA proofer' do
          expect(plugin.proofer).to receive(:proof).with(hash_including(state_id_address))
          call
        end

        it 'tracks an SP cost for AAMVA' do
          expect { call }.to(
            change { sp_cost_count_with_transaction_id }
              .to(1),
          )
        end

        context 'AAMVA proofer raises an exception' do
          let(:proofer_result) do
            Proofing::StateIdResult.new(
              success: false,
              transaction_id: 'aamva-123',
              exception: RuntimeError.new('this is a fun test error!!'),
            )
          end

          it 'does not track an SP cost for AAMVA' do
            expect { call }.to_not change { sp_cost_count_for_issuer }
          end
        end

        context 'applicant submitted a passport' do
          let(:applicant_pii) { Idp::Constants::MOCK_IDV_PROOFING_PASSPORT_APPLICANT }

          it 'returns a skipped result' do
            call.tap do |result|
              expect(result.success?).to eql(true)
              expect(result.vendor_name).to eql(Idp::Constants::Vendors::AAMVA_CHECK_SKIPPED)
            end
          end

          it 'does not make an AAMVA call' do
            expect(plugin.proofer).not_to receive(:proof)
            call
          end

          it 'does not track an SP cost for AAMVA' do
            expect { call }.not_to change { sp_cost_count_for_issuer }
          end
        end
      end

      context 'InstantVerify failed' do
        context 'and the failure can possibly be covered by AAMVA' do
          let(:state_id_address_resolution_result) do
            Proofing::Resolution::Result.new(
              success: false,
              vendor_name: 'lexisnexis:instant_verify',
              failed_result_can_pass_with_additional_verification: true,
              attributes_requiring_additional_verification: [:address],
            )
          end

          it 'makes an AAMVA call' do
            expect(plugin.proofer).to receive(:proof)
            call
          end

          it 'tracks an SP cost for AAMVA' do
            expect { call }
              .to(
                change { sp_cost_count_with_transaction_id }
                .to(1),
              )
          end
        end

        context 'but the failure cannot be covered by AAMVA' do
          let(:state_id_address_resolution_result) do
            Proofing::Resolution::Result.new(
              success: false,
              vendor_name: 'lexisnexis:instant_verify',
              failed_result_can_pass_with_additional_verification: false,
            )
          end

          it 'does not make an AAMVA call' do
            expect(plugin.proofer).not_to receive(:proof)
            call
          end

          it 'does not record an SP cost for AAMVA' do
            expect { call }.not_to change { sp_cost_count_for_issuer }
          end

          it 'returns an UnsupportedJurisdiction result' do
            call.tap do |result|
              expect(result.success?).to eql(true)
              expect(result.vendor_name).to eql('UnsupportedJurisdiction')
            end
          end
        end
      end
    end

    context 'in-person proofing' do
      let(:ipp_enrollment_in_progress) { true }

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

      context 'residential address same as id address' do
        let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID }

        let(:state_id_address_resolution_result) do
          Proofing::Resolution::Result.new(
            success: true,
            vendor_name: 'lexisnexis:instant_verify',
          )
        end

        context 'InstantVerify succeeded' do
          it 'calls the AAMVA proofer' do
            expect(plugin.proofer).to receive(:proof).with(hash_including(state_id_address))
            call
          end

          it 'records an SP cost for AAMVA' do
            expect { call }.to change { sp_cost_count_with_transaction_id }.to(1)
          end
        end

        context 'InstantVerify failed' do
          context 'and the failure can possibly be covered by AAMVA' do
            let(:state_id_address_resolution_result) do
              Proofing::Resolution::Result.new(
                success: false,
                vendor_name: 'lexisnexis:instant_verify',
                failed_result_can_pass_with_additional_verification: true,
                attributes_requiring_additional_verification: [:address],
              )
            end

            it 'makes an AAMVA call' do
              expect(plugin.proofer).to receive(:proof)
              call
            end

            it 'records an SP cost for AAMVA' do
              expect { call }.to change { sp_cost_count_with_transaction_id }.to(1)
            end
          end

          context 'but the failure cannot be covered by AAMVA' do
            let(:state_id_address_resolution_result) do
              Proofing::Resolution::Result.new(
                success: false,
                vendor_name: 'lexisnexis:instant_verify',
                failed_result_can_pass_with_additional_verification: false,
              )
            end

            it 'does not make an AAMVA call' do
              expect(plugin.proofer).not_to receive(:proof)
              call
            end

            it 'does not record an SP cost for AAMVA' do
              expect { call }.not_to change { sp_cost_count_for_issuer }
            end

            it 'returns an UnsupportedJurisdiction result' do
              call.tap do |result|
                expect(result.success?).to eql(true)
                expect(result.vendor_name).to eql('UnsupportedJurisdiction')
              end
            end
          end
        end
      end

      context 'residential address and id address are different' do
        let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS }

        context 'InstantVerify succeeded for residential address' do
          context 'and InstantVerify passed for id address' do
            let(:state_id_address_resolution_result) do
              Proofing::Resolution::Result.new(
                success: true,
                vendor_name: 'lexisnexis:instant_verify',
              )
            end

            it 'calls the AAMVA proofer using the state id address' do
              expect(plugin.proofer).to receive(:proof).with(hash_including(state_id_address))
              call
            end

            it 'records an SP cost for AAMVA' do
              expect { call }.to change { sp_cost_count_with_transaction_id }.to(1)
            end
          end

          context 'and InstantVerify failed for state id address' do
            context 'but the failure can possibly be covered by AAMVA' do
              let(:state_id_address_resolution_result) do
                Proofing::Resolution::Result.new(
                  success: false,
                  vendor_name: 'lexisnexis:instant_verify',
                  failed_result_can_pass_with_additional_verification: true,
                  attributes_requiring_additional_verification: [:address],
                )
              end

              it 'does not make an AAMVA call because get to yes is not supported' do
                expect(plugin.proofer).not_to receive(:proof)
                call
              end

              it 'does not record an SP cost for AAMVA' do
                expect { call }.not_to change { sp_cost_count_for_issuer }
              end
            end

            context 'and the failure cannot be covered by AAMVA' do
              let(:state_id_address_resolution_result) do
                Proofing::Resolution::Result.new(
                  success: false,
                  vendor_name: 'lexisnexis:instant_verify',
                  failed_result_can_pass_with_additional_verification: false,
                )
              end

              it 'does not make an AAMVA call' do
                expect(plugin.proofer).not_to receive(:proof)
                call
              end

              it 'does not record an SP cost for AAMVA' do
                expect { call }.not_to change { sp_cost_count_for_issuer }
              end

              it 'returns an UnsupportedJurisdiction result' do
                call.tap do |result|
                  expect(result.success?).to eql(true)
                  expect(result.vendor_name).to eql('UnsupportedJurisdiction')
                end
              end
            end
          end
        end
      end
    end

    context 'ad hoc proofing' do
      let(:analytics) { FakeAnalytics.new }
      let(:doc_auth_flow) { true }

      subject(:call) do
        plugin.call(
          applicant_pii:,
          current_sp:,
          state_id_address_resolution_result: nil,
          ipp_enrollment_in_progress:,
          timer: JobHelpers::Timer.new,
          analytics:,
          doc_auth_flow:,
        )
      end

      context 'when the state ID can proof' do
        let(:state) { 'WA' }
        let(:state_id_jurisdiction) { 'WA' }

        context 'when an ipp enrollment is in progress' do
          let(:ipp_enrollment_in_progress) { true }
          let(:applicant_pii) do
            Idp::Constants::MOCK_IPP_APPLICANT.merge(state:, state_id_jurisdiction:)
          end
          let(:proofing_pii) do
            {
              first_name: applicant_pii[:first_name],
              last_name: applicant_pii[:last_name],
              dob: applicant_pii[:dob],
              same_address_as_id: applicant_pii[:same_address_as_id],
              state_id_expiration: applicant_pii[:state_id_expiration],
              state_id_jurisdiction: applicant_pii[:state_id_jurisdiction],
              state_id_number: applicant_pii[:state_id_number],
              address1: applicant_pii[:identity_doc_address1],
              address2: applicant_pii[:identity_doc_address2],
              city: applicant_pii[:identity_doc_city],
              state: applicant_pii[:identity_doc_address_state],
              zipcode: applicant_pii[:identity_doc_zipcode],
            }
          end

          before do
            allow(proofer).to receive(:proof).with(proofing_pii).and_return(proofer_result)
          end

          context 'when the aamva request is successful' do
            let(:proofer_result) do
              Proofing::StateIdResult.new(
                success: true,
                vendor_name: 'state_id:aamva',
                transaction_id: proofer_transaction_id,
                requested_attributes: {
                  first_name: 1,
                  last_name: 1,
                  dob: 1,
                  state_id_number: 1,
                  document_type_received: 1,
                  state_id_expiration: 1,
                  state_id_jurisdiction: 1,
                  state_id_issued: 1,
                  height: 1,
                  sex: 1,
                  address: 1,
                },
                verified_attributes: [
                  'first_name',
                  'last_name',
                  'state_id_number',
                  'dob',
                  'document_type_received',
                  'state_id_expiration',
                  'state_id_jurisdiction',
                  'state_id_issued',
                  'height',
                  'sex',
                  'address',
                ],
              )
            end
            let(:proofer_result_hash) { proofer_result.to_h }

            before do
              allow(proofer).to receive(:proof).with(applicant_pii).and_return(proofer_result)
            end

            it 'returns a successful result', :aggregate_failures do
              call.tap do |result|
                expect(result).to be_an_instance_of(Proofing::StateIdResult)
                expect(result.success?).to eq(true)
              end
            end

            it 'tracks an SP cost' do
              expect { call }.to(
                change { sp_cost_count_with_transaction_id }
                  .to(1),
              )
            end

            it 'logs a idv_state_id_validation event' do
              call
              expect(analytics).to have_logged_event(
                :idv_state_id_validation, {
                  success: proofer_result_hash[:success],
                  errors: proofer_result_hash[:errors],
                  timed_out: proofer_result_hash[:timed_out],
                  vendor_name: proofer_result_hash[:vendor_name],
                  transaction_id: proofer_result_hash[:transaction_id],
                  requested_attributes: proofer_result_hash[:requested_attributes],
                  verified_attributes: proofer_result_hash[:verified_attributes],
                  supported_jurisdiction: true,
                  jurisdiction_in_maintenance_window:
                    proofer_result_hash[:jurisdiction_in_maintenance_window],
                  ipp_enrollment_in_progress: true,
                  birth_year: applicant_pii[:dob].to_date.year,
                  state: applicant_pii[:state],
                  state_id_jurisdiction: applicant_pii[:state_id_jurisdiction],
                  state_id_number: '#' * applicant_pii[:state_id_number].length,
                }
              )
            end
          end

          context 'when the aamva response is unsuccessful' do
            let(:proofer_result) do
              Proofing::StateIdResult.new(
                success: false,
                vendor_name: 'state_id:aamva',
                transaction_id: proofer_transaction_id,
                requested_attributes: {
                  first_name: 1,
                  last_name: 1,
                  dob: 1,
                  state_id_number: 1,
                  document_type_received: 1,
                  state_id_expiration: 1,
                  state_id_jurisdiction: 1,
                  state_id_issued: 1,
                  height: 1,
                  sex: 1,
                  address: 1,
                },
                verified_attributes: [],
                errors: {
                  state_id_expiration: ['MISSING'],
                  state_id_issued: ['MISSING'],
                  state_id_number: ['UNVERIFIED'],
                  document_type_received: ['MISSING'],
                  dob: ['MISSING'],
                  height: ['MISSING'],
                  sex: ['MISSING'],
                  weight: ['MISSING'],
                  eye_color: ['MISSING'],
                  last_name: ['MISSING'],
                  first_name: ['MISSING'],
                  middle_name: ['MISSING'],
                  name_suffix: ['MISSING'],
                  address1: ['MISSING'],
                  address2: ['MISSING'],
                  city: ['MISSING'],
                  state: ['MISSING'],
                  zipcode: ['MISSING'],
                },
              )
            end
            let(:proofer_result_hash) { proofer_result.to_h }

            it 'returns a unsuccessful result', :aggregate_failures do
              call.tap do |result|
                expect(result).to be_an_instance_of(Proofing::StateIdResult)
                expect(result.success?).to eq(false)
                expect(result.vendor_name).to eq('state_id:aamva')
              end
            end

            it 'tracks an SP cost' do
              expect { call }.to(
                change { sp_cost_count_with_transaction_id }
                  .to(1),
              )
            end

            it 'logs a idv_state_id_validation event' do
              call
              expect(analytics).to have_logged_event(
                :idv_state_id_validation, {
                  success: proofer_result_hash[:success],
                  errors: proofer_result_hash[:errors],
                  timed_out: proofer_result_hash[:timed_out],
                  vendor_name: proofer_result_hash[:vendor_name],
                  transaction_id: proofer_result_hash[:transaction_id],
                  requested_attributes: proofer_result_hash[:requested_attributes],
                  verified_attributes: proofer_result_hash[:verified_attributes],
                  supported_jurisdiction: true,
                  jurisdiction_in_maintenance_window:
                    proofer_result_hash[:jurisdiction_in_maintenance_window],
                  ipp_enrollment_in_progress: true,
                  birth_year: applicant_pii[:dob].to_date.year,
                  state: applicant_pii[:state],
                  state_id_jurisdiction: applicant_pii[:state_id_jurisdiction],
                  state_id_number: '#' * applicant_pii[:state_id_number].length,
                }
              )
            end
          end

          context 'when the aamva response has an exception' do
            let(:proofer_result) do
              Proofing::StateIdResult.new(
                success: false,
                vendor_name: 'state_id:aamva',
                transaction_id: proofer_transaction_id,
                exception: RuntimeError.new('I am error!'),
              )
            end
            let(:proofer_result_hash) { proofer_result.to_h }

            it 'returns a unsuccessful result', :aggregate_failures do
              call.tap do |result|
                expect(result).to be_an_instance_of(Proofing::StateIdResult)
                expect(result.success?).to eq(false)
                expect(result.vendor_name).to eq('state_id:aamva')
              end
            end

            it 'does not track an SP cost' do
              expect { call }.to_not change { sp_cost_count_with_transaction_id }
            end

            it 'logs a idv_state_id_validation event' do
              call
              expect(analytics).to have_logged_event(
                :idv_state_id_validation, {
                  success: proofer_result_hash[:success],
                  errors: proofer_result_hash[:errors],
                  exception: proofer_result_hash[:exception],
                  mva_exception: proofer_result_hash[:mva_exception],
                  timed_out: proofer_result_hash[:timed_out],
                  vendor_name: proofer_result_hash[:vendor_name],
                  transaction_id: proofer_result_hash[:transaction_id],
                  requested_attributes: proofer_result_hash[:requested_attributes],
                  verified_attributes: proofer_result_hash[:verified_attributes],
                  supported_jurisdiction: true,
                  jurisdiction_in_maintenance_window:
                    proofer_result_hash[:jurisdiction_in_maintenance_window],
                  ipp_enrollment_in_progress: true,
                  birth_year: applicant_pii[:dob].to_date.year,
                  state: applicant_pii[:state],
                  state_id_jurisdiction: applicant_pii[:state_id_jurisdiction],
                  state_id_number: '#' * applicant_pii[:state_id_number].length,
                }
              )
            end
          end
        end

        context 'when an ipp enrollment is not in progress' do
          let(:ipp_enrollment_in_progress) { false }
          let(:applicant_pii) do
            Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.merge(state:, state_id_jurisdiction:)
          end

          before do
            allow(proofer).to receive(:proof).with(applicant_pii).and_return(proofer_result)
          end

          context 'when the aamva response is successful' do
            let(:proofer_result) do
              Proofing::StateIdResult.new(
                success: true,
                vendor_name: 'state_id:aamva',
                transaction_id: proofer_transaction_id,
              )
            end
            let(:proofer_result_hash) { proofer_result.to_h }

            it 'returns a successful result', :aggregate_failures do
              call.tap do |result|
                expect(result).to be_an_instance_of(Proofing::StateIdResult)
                expect(result.success?).to eq(true)
              end
            end

            it 'tracks an SP cost' do
              expect { call }.to(
                change { sp_cost_count_with_transaction_id }
                  .to(1),
              )
            end

            it 'logs a idv_state_id_validation event' do
              call
              expect(analytics).to have_logged_event(
                :idv_state_id_validation, {
                  success: proofer_result_hash[:success],
                  errors: proofer_result_hash[:errors],
                  timed_out: proofer_result_hash[:timed_out],
                  vendor_name: proofer_result_hash[:vendor_name],
                  transaction_id: proofer_result_hash[:transaction_id],
                  requested_attributes: proofer_result_hash[:requested_attributes],
                  verified_attributes: proofer_result_hash[:verified_attributes],
                  supported_jurisdiction: true,
                  jurisdiction_in_maintenance_window:
                    proofer_result_hash[:jurisdiction_in_maintenance_window],
                  ipp_enrollment_in_progress: false,
                  birth_year: applicant_pii[:dob].to_date.year,
                  state: applicant_pii[:state],
                  state_id_jurisdiction: applicant_pii[:state_id_jurisdiction],
                  state_id_number: '#' * applicant_pii[:state_id_number].length,
                }
              )
            end
          end

          context 'when the aamva response is unsuccessful' do
            let(:proofer_result) do
              Proofing::StateIdResult.new(
                success: false,
                vendor_name: 'state_id:aamva',
                transaction_id: proofer_transaction_id,
                requested_attributes: {
                  first_name: 1,
                  last_name: 1,
                  dob: 1,
                  state_id_number: 1,
                  document_type_received: 1,
                  state_id_expiration: 1,
                  state_id_jurisdiction: 1,
                  state_id_issued: 1,
                  height: 1,
                  sex: 1,
                  address: 1,
                },
                verified_attributes: [],
                errors: {
                  state_id_expiration: ['MISSING'],
                  state_id_issued: ['MISSING'],
                  state_id_number: ['UNVERIFIED'],
                  document_type_received: ['MISSING'],
                  dob: ['MISSING'],
                  height: ['MISSING'],
                  sex: ['MISSING'],
                  weight: ['MISSING'],
                  eye_color: ['MISSING'],
                  last_name: ['MISSING'],
                  first_name: ['MISSING'],
                  middle_name: ['MISSING'],
                  name_suffix: ['MISSING'],
                  address1: ['MISSING'],
                  address2: ['MISSING'],
                  city: ['MISSING'],
                  state: ['MISSING'],
                  zipcode: ['MISSING'],
                },
              )
            end
            let(:proofer_result_hash) { proofer_result.to_h }

            it 'returns a unsuccessful result', :aggregate_failures do
              call.tap do |result|
                expect(result).to be_an_instance_of(Proofing::StateIdResult)
                expect(result.success?).to eq(false)
                expect(result.vendor_name).to eq('state_id:aamva')
              end
            end

            it 'tracks an SP cost for AAMVA' do
              expect { call }.to(
                change { sp_cost_count_with_transaction_id }
                  .to(1),
              )
            end

            it 'logs a idv_state_id_validation event' do
              call
              expect(analytics).to have_logged_event(
                :idv_state_id_validation, {
                  success: proofer_result_hash[:success],
                  errors: proofer_result_hash[:errors],
                  timed_out: proofer_result_hash[:timed_out],
                  vendor_name: proofer_result_hash[:vendor_name],
                  transaction_id: proofer_result_hash[:transaction_id],
                  requested_attributes: proofer_result_hash[:requested_attributes],
                  verified_attributes: proofer_result_hash[:verified_attributes],
                  supported_jurisdiction: true,
                  jurisdiction_in_maintenance_window:
                    proofer_result_hash[:jurisdiction_in_maintenance_window],
                  ipp_enrollment_in_progress: false,
                  birth_year: applicant_pii[:dob].to_date.year,
                  state: applicant_pii[:state],
                  state_id_jurisdiction: applicant_pii[:state_id_jurisdiction],
                  state_id_number: '#' * applicant_pii[:state_id_number].length,
                }
              )
            end
          end

          context 'when the aamva response has an exception' do
            let(:proofer_result) do
              Proofing::StateIdResult.new(
                success: false,
                vendor_name: 'state_id:aamva',
                transaction_id: proofer_transaction_id,
                exception: RuntimeError.new('I am error!'),
              )
            end
            let(:proofer_result_hash) { proofer_result.to_h }

            it 'returns a unsuccessful result', :aggregate_failures do
              call.tap do |result|
                expect(result).to be_an_instance_of(Proofing::StateIdResult)
                expect(result.success?).to eq(false)
                expect(result.vendor_name).to eq('state_id:aamva')
              end
            end

            it 'does not track an SP cost' do
              expect { call }.to_not change { sp_cost_count_with_transaction_id }
            end

            it 'logs a idv_state_id_validation event' do
              call
              expect(analytics).to have_logged_event(
                :idv_state_id_validation, {
                  success: proofer_result_hash[:success],
                  errors: proofer_result_hash[:errors],
                  exception: proofer_result_hash[:exception],
                  mva_exception: proofer_result_hash[:mva_exception],
                  timed_out: proofer_result_hash[:timed_out],
                  vendor_name: proofer_result_hash[:vendor_name],
                  transaction_id: proofer_result_hash[:transaction_id],
                  requested_attributes: proofer_result_hash[:requested_attributes],
                  verified_attributes: proofer_result_hash[:verified_attributes],
                  supported_jurisdiction: true,
                  jurisdiction_in_maintenance_window:
                    proofer_result_hash[:jurisdiction_in_maintenance_window],
                  ipp_enrollment_in_progress: false,
                  birth_year: applicant_pii[:dob].to_date.year,
                  state: applicant_pii[:state],
                  state_id_jurisdiction: applicant_pii[:state_id_jurisdiction],
                  state_id_number: '#' * applicant_pii[:state_id_number].length,
                }
              )
            end
          end
        end
      end

      context 'when the state ID cannot proof' do
        let(:state) { 'NP' }
        let(:state_id_jurisdiction) { 'NP' }

        let(:applicant_pii) do
          Idp::Constants::MOCK_IPP_APPLICANT.merge(state:, state_id_jurisdiction:)
        end
        let(:proofer_result_hash) do
          Proofing::StateIdResult.new(
            success: true,
            vendor_name: Idp::Constants::Vendors::AAMVA_UNSUPPORTED_JURISDICTION,
          ).to_h
        end

        it 'returns an unsupported jurisdiction result' do
          call.tap do |result|
            expect(result).to be_an_instance_of(Proofing::StateIdResult)
            expect(result.success?).to eq(true)
            expect(result.vendor_name).to eq(
              Idp::Constants::Vendors::AAMVA_UNSUPPORTED_JURISDICTION,
            )
          end
        end

        it 'logs a idv_state_id_validation event' do
          call
          expect(analytics).to have_logged_event(
            :idv_state_id_validation, {
              success: proofer_result_hash[:success],
              errors: proofer_result_hash[:errors],
              timed_out: proofer_result_hash[:timed_out],
              vendor_name: proofer_result_hash[:vendor_name],
              transaction_id: proofer_result_hash[:transaction_id],
              requested_attributes: proofer_result_hash[:requested_attributes],
              verified_attributes: proofer_result_hash[:verified_attributes],
              supported_jurisdiction: false,
              jurisdiction_in_maintenance_window:
                proofer_result_hash[:jurisdiction_in_maintenance_window],
              ipp_enrollment_in_progress: false,
              birth_year: applicant_pii[:dob].to_date.year,
              state: applicant_pii[:state],
              state_id_jurisdiction: applicant_pii[:state_id_jurisdiction],
              state_id_number: '#' * applicant_pii[:state_id_number].length,
            }
          )
        end
      end
    end
  end

  describe '#aamva_supports_state_id_jurisdiction?' do
    let(:applicant_pii) do
      Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.merge(
        state: address_state,
        state_id_jurisdiction: jurisdiction_state,
      )
    end
    let(:jurisdiction_state) { 'WA' }
    let(:address_state) { 'WA' }
    let(:aamva_supported_jurisdictions) do
      ['WA']
    end

    subject(:supported) do
      described_class.new.aamva_supports_state_id_jurisdiction?(applicant_pii)
    end

    before do
      allow(IdentityConfig.store).to receive(:aamva_supported_jurisdictions)
        .and_return(aamva_supported_jurisdictions)
    end

    context 'when jurisdiction is supported' do
      it 'returns true' do
        expect(supported).to eql(true)
      end
      context 'but address state is not' do
        let(:address_state) { 'MT' }
        it 'still returns true' do
          expect(supported).to eql(true)
        end
      end
    end

    context 'when jurisdiction is not supported' do
      let(:address_state) { 'MT' }
      let(:jurisdiction_state) { 'MT' }

      it 'returns false' do
        expect(supported).to eql(false)
      end

      context 'but address state is' do
        let(:address_state) { 'WA' }
        it 'still returns false' do
          expect(supported).to eql(false)
        end
      end
    end
  end

  describe '#skipped_result' do
    it 'returns a check skipped result' do
      plugin.skipped_result.tap do |result|
        expect(result.success?).to eql(true)
        expect(result.vendor_name).to eql(Idp::Constants::Vendors::AAMVA_CHECK_SKIPPED)
      end
    end
  end

  describe '#passport_applicant?' do
    context 'with new field name (document_type_received)' do
      let(:applicant_pii) do
        {
          document_type_received: 'passport',
          first_name: 'Test',
          last_name: 'User',
        }
      end

      it 'correctly identifies passport applicant' do
        expect(described_class.new.send(:passport_applicant?, applicant_pii)).to be true
      end
    end

    context 'with old field name (id_doc_type)' do
      let(:applicant_pii) do
        {
          id_doc_type: 'passport',
          first_name: 'Test',
          last_name: 'User',
        }
      end

      it 'correctly identifies passport applicant using old field name' do
        expect(described_class.new.send(:passport_applicant?, applicant_pii)).to be true
      end
    end

    context 'with both field names present (new takes precedence)' do
      let(:applicant_pii) do
        {
          document_type_received: 'passport',
          id_doc_type: 'drivers_license',
          first_name: 'Test',
          last_name: 'User',
        }
      end

      it 'uses new field name when both are present' do
        expect(described_class.new.send(:passport_applicant?, applicant_pii)).to be true
      end
    end

    context 'with non-passport document using new field' do
      let(:applicant_pii) do
        {
          document_type_received: 'drivers_license',
          first_name: 'Test',
          last_name: 'User',
        }
      end

      it 'correctly identifies non-passport applicant' do
        expect(described_class.new.send(:passport_applicant?, applicant_pii)).to be false
      end
    end

    context 'with non-passport document using old field' do
      let(:applicant_pii) do
        {
          id_doc_type: 'drivers_license',
          first_name: 'Test',
          last_name: 'User',
        }
      end

      it 'correctly identifies non-passport applicant using old field' do
        expect(described_class.new.send(:passport_applicant?, applicant_pii)).to be false
      end
    end

    context 'with neither field present' do
      let(:applicant_pii) do
        {
          first_name: 'Test',
          last_name: 'User',
        }
      end

      it 'returns false when document type is not specified' do
        expect(described_class.new.send(:passport_applicant?, applicant_pii)).to be false
      end
    end
  end

  context 'when already_proofed is true' do
    let(:already_proofed) { true }
    it 'returns a skipped result without calling the proofer' do
      expect(plugin.proofer).not_to receive(:proof)
      plugin.call(
        applicant_pii:,
        current_sp:,
        state_id_address_resolution_result:,
        ipp_enrollment_in_progress:,
        timer: JobHelpers::Timer.new,
        already_proofed:,
      ).tap do |result|
        expect(result.success?).to eql(true)
        expect(result.vendor_name).to eql(Idp::Constants::Vendors::AAMVA_CHECK_SKIPPED)
      end
    end
  end
end
