require 'rails_helper'

RSpec.describe Proofing::Resolution::Plugins::AamvaPlugin do
  let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN }
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
            change { sp_cost_count_with_transaction_id }.
              to(1),
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
            expect { call }.
              to(
                change { sp_cost_count_with_transaction_id }.
                to(1),
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
      allow(IdentityConfig.store).to receive(:aamva_supported_jurisdictions).
        and_return(aamva_supported_jurisdictions)
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
end
