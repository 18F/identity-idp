require 'rails_helper'

RSpec.describe Proofing::Resolution::Plugins::InstantVerifyStateIdAddressPlugin do
  let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID }

  let(:current_sp) { build(:service_provider) }

  let(:residential_address_resolution_result) do
    Proofing::Resolution::Result.new(
      success: true,
      errors: {},
      exception: nil,
      vendor_name: 'lexisnexis:instant_verify',
    )
  end

  let(:ipp_enrollment_in_progress) { true }

  let(:proofer_result) do
    Proofing::Resolution::Result.new(
      success: true,
      errors: {},
      exception: nil,
      vendor_name: 'lexisnexis:instant_verify',
    )
  end

  subject(:plugin) do
    described_class.new
  end

  before do
    allow(plugin.proofer).to receive(:proof).and_return(proofer_result)
  end

  describe '#call' do
    subject(:call) do
      plugin.call(
        applicant_pii:,
        current_sp:,
        ipp_enrollment_in_progress:,
        residential_address_resolution_result:,
        timer: JobHelpers::Timer.new,
      )
    end

    context 'remote unsupervised proofing' do
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

      it 'passes state id address to proofer' do
        expect(plugin.proofer).
          to receive(:proof).
          with(hash_including(state_id_address)).
          and_call_original

        call
      end

      context 'when InstantVerify call succeeds' do
        it 'returns the proofer result' do
          expect(call).to eql(proofer_result)
        end

        it 'records a LexisNexis SP cost' do
          expect { call }.
            to change {
                 SpCost.where(
                   cost_type: :lexis_nexis_resolution,
                   issuer: current_sp.issuer,
                 ).count
               }.to(1)
        end
      end

      context 'when InstantVerify call fails' do
        let(:proofer_result) do
          Proofing::Resolution::Result.new(
            success: false,
            errors: {},
            exception: nil,
            vendor_name: 'lexisnexis:instant_verify',
          )
        end

        it 'returns the proofer result' do
          expect(call).to eql(proofer_result)
        end

        it 'records a LexisNexis SP cost' do
          expect { call }.
            to change {
                 SpCost.where(
                   cost_type: :lexis_nexis_resolution,
                   issuer: current_sp.issuer,
                 ).count
               }.to(1)
        end
      end

      context 'when InstantVerify call results in exception' do
        let(:proofer_result) do
          Proofing::Resolution::Result.new(
            success: false,
            errors: {},
            exception: RuntimeError.new(':ohno:'),
            vendor_name: 'lexisnexis:instant_verify',
          )
        end

        it 'returns the proofer result' do
          expect(call).to eql(proofer_result)
        end

        it 'records a LexisNexis SP cost' do
          expect { call }.
            to change {
                 SpCost.where(
                   cost_type: :lexis_nexis_resolution,
                   issuer: current_sp.issuer,
                 ).count
               }.to(1)
        end
      end
    end

    context 'in person proofing' do
      context 'residential address and id address are the same' do
        it 'reuses residential address result' do
          result = call
          expect(plugin.proofer).not_to have_received(:proof)
          expect(result).to eql(residential_address_resolution_result)
        end

        it 'does not add a new LexisNexis SP cost (since residential address result was reused)' do
          expect { call }.
            not_to change {
              SpCost.where(
                cost_type: :lexis_nexis_resolution,
                issuer: current_sp.issuer,
              ).count
            }
        end
      end

      context 'residential address and id address are diferent' do
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
          it 'calls the InstantVerify Proofer with state id address' do
            expect(plugin.proofer).to receive(:proof).with(hash_including(state_id_address)).
              and_call_original

            call
          end

          context 'when InstantVerify call succeeds' do
            it 'returns the proofer result' do
              expect(call).to eql(proofer_result)
            end

            it 'records a LexisNexis SP cost' do
              expect { call }.
                to change {
                     SpCost.where(
                       cost_type: :lexis_nexis_resolution,
                       issuer: current_sp.issuer,
                     ).count
                   }.to(1)
            end
          end

          context 'when InstantVerify call fails' do
            let(:proofer_result) do
              Proofing::Resolution::Result.new(
                success: false,
                errors: {},
                exception: nil,
                vendor_name: 'lexisnexis:instant_verify',
              )
            end

            it 'returns the proofer result' do
              expect(call).to eql(proofer_result)
            end

            it 'records a LexisNexis SP cost' do
              expect { call }.
                to change {
                     SpCost.where(
                       cost_type: :lexis_nexis_resolution,
                       issuer: current_sp.issuer,
                     ).count
                   }.to(1)
            end
          end

          context 'when InstantVerify call results in exception' do
            let(:proofer_result) do
              Proofing::Resolution::Result.new(
                success: false,
                errors: {},
                exception: RuntimeError.new(':ohno:'),
                vendor_name: 'lexisnexis:instant_verify',
              )
            end

            it 'returns the proofer result' do
              expect(call).to eql(proofer_result)
            end

            it 'records a LexisNexis SP cost' do
              expect { call }.
                to change {
                     SpCost.where(
                       cost_type: :lexis_nexis_resolution,
                       issuer: current_sp.issuer,
                     ).count
                   }.to(1)
            end
          end

          context 'LexisNexis InstantVerify failed for residential address' do
            let(:residential_address_resolution_result) do
              Proofing::Resolution::Result.new(
                success: false,
                errors: {},
                exception: nil,
                vendor_name: 'lexisnexis:instant_verify',
              )
            end

            it 'does not make unnecessary calls' do
              expect(plugin.proofer).not_to receive(:proof)
              call
            end

            it 'does not record an additional LexisNexis SP cost' do
              expect { call }.
                not_to change {
                         SpCost.where(
                           cost_type: :lexis_nexis_resolution,
                           issuer: current_sp.issuer,
                         ).count
                       }
            end

            it 'returns a ResolutionCannotPass result' do
              call.tap do |result|
                expect(result.success?).to eql(false)
                expect(result.vendor_name).to eql('ResolutionCannotPass')
              end
            end
          end
        end
      end
    end
  end
end
