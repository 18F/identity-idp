require 'rails_helper'

RSpec.describe Proofing::Resolution::Plugins::AamvaPlugin do
  let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN }

  let(:current_sp) { build(:service_provider) }

  let(:instant_verify_result) { nil }

  let(:ipp_enrollment_in_progress) { false }

  let(:proofer) { instance_double(Proofing::Aamva::Proofer, proof: proofer_result) }

  let(:proofer_result) do
    Proofing::StateIdResult.new(
      success: true,
      vendor_name: 'state_id:aamva',
    )
  end

  subject(:plugin) do
    described_class.new
  end

  before do
    allow(plugin).to receive(:proofer).and_return(proofer)
  end

  describe '#call' do
    subject(:call) do
      plugin.call(
        applicant_pii:,
        current_sp:,
        instant_verify_result:,
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
        let(:instant_verify_result) do
          Proofing::Resolution::Result.new(
            success: true,
            vendor_name: 'lexisnexis:instant_verify',
          )
        end

        it 'calls the AAMVA proofer' do
          expect(plugin.proofer).to receive(:proof).with(hash_including(state_id_address))
          call
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
            expect { call }.to_not change { SpCost.where(cost_type: :aamva).count }
          end
        end
      end

      context 'InstantVerify failed' do
        context 'and the failure can possibly be covered by AAMVA' do
          let(:instant_verify_result) do
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
              to change {
                   SpCost.where(cost_type: :aamva, issuer: current_sp.issuer).count
                 }.to eql(1)
          end
        end

        context 'but the failure cannot be covered by AAMVA' do
          let(:instant_verify_result) do
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

        let(:instant_verify_result) do
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
        end

        context 'InstantVerify failed' do
          context 'and the failure can possibly be covered by AAMVA' do
            let(:instant_verify_result) do
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
          end

          context 'but the failure cannot be covered by AAMVA' do
            let(:instant_verify_result) do
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
            let(:instant_verify_result) do
              Proofing::Resolution::Result.new(
                success: true,
                vendor_name: 'lexisnexis:instant_verify',
              )
            end

            it 'calls the AAMVA proofer using the state id address' do
              expect(plugin.proofer).to receive(:proof).with(hash_including(state_id_address))
              call
            end
          end

          context 'and InstantVerify failed for state id address' do
            context 'but the failure can possibly be covered by AAMVA' do
              let(:instant_verify_result) do
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
            end

            context 'and the failure cannot be covered by AAMVA' do
              let(:instant_verify_result) do
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
end
