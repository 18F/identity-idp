require 'rails_helper'

RSpec.describe Proofing::AddressProofer do
  let(:user_uuid) { Faker::Internet.uuid }
  let(:user_email) { Faker::Internet.email }
  let(:ddp_phone_finder_proofer) { instance_double(Proofing::LexisNexis::Ddp::Proofers::PhoneFinderProofer) }
  let(:ddp_phone_finder_result) do
    Proofing::AddressResult.new(
      success: true,
      errors: [],
      exception: nil,
      vendor_name: 'lexisnexis:phone_finder_ddp',
      transaction_id: Faker::Internet.uuid,
    )
  end
  let(:phone_risk_proofer) { instance_double(Proofing::Socure::IdPlus::Proofers::PhoneRiskProofer) }
  let(:socure_phone_risk_result) do
    Proofing::AddressResult.new(
      success: true,
      errors: [],
      exception: nil,
      vendor_name: 'socure_phonerisk',
      transaction_id: Faker::Internet.uuid,
    )
  end

  subject { described_class.new(user_uuid:, user_email:) }

  before do
    allow(ddp_phone_finder_proofer).to receive(:proof).and_return(ddp_phone_finder_result)
    allow(Proofing::LexisNexis::Ddp::Proofers::PhoneFinderProofer).to receive(:new)
      .and_return(ddp_phone_finder_proofer)
    allow(phone_risk_proofer).to receive(:proof).and_return(socure_phone_risk_result)
    allow(Proofing::Socure::IdPlus::Proofers::PhoneRiskProofer).to receive(:new)
      .and_return(phone_risk_proofer)
  end

  describe '#proof' do
    let(:applicant_pii) do
      {
        first_name: Faker::Name.first_name,
        last_name: Faker::Name.last_name,
      }
    end
    let(:service_provider) { Faker::Business.name }

    context 'when dual vendor check is disabled' do
      before do
        allow(FeatureManagement).to receive(:dual_vendor_check_enabled?).and_return(false)
      end

      context 'when secondary address proofer is not configured' do
        before do
          allow(IdentityConfig.store).to receive(:idv_address_secondary_vendor).and_return(nil)
          allow(IdentityConfig.store).to receive(:idv_address_vendor_socure_percent).and_return(0)
        end

        context 'when the primary vendor is lexis_nexis_ddp' do
          before do
            allow(IdentityConfig.store).to receive(:idv_address_primary_vendor)
              .and_return(:lexis_nexis_ddp)
            expect(Db::SpCost::AddSpCost).to receive(:call).with(
              service_provider,
              :lexis_nexis_address,
              transaction_id: ddp_phone_finder_result.transaction_id,
            )
          end

          it 'returns a lexis_nexis_ddp hash result' do
            expect(subject.proof(applicant_pii:, current_sp: service_provider)).to eq(
              ddp_phone_finder_result.to_h,
            )
          end
        end

        context 'when the primary vendor is socure' do
          before do
            allow(IdentityConfig.store).to receive(:idv_address_primary_vendor)
              .and_return(:socure)
            expect(Db::SpCost::AddSpCost).to receive(:call).with(
              service_provider,
              :socure_address,
              transaction_id: socure_phone_risk_result.transaction_id,
            )
          end

          it 'returns a socure hash result' do
            expect(subject.proof(applicant_pii:, current_sp: service_provider)).to eq(
              socure_phone_risk_result.to_h,
            )
          end
        end

        context 'when a primary vendor is configured' do
          before do
            allow(IdentityConfig.store).to receive(:idv_address_primary_vendor)
              .and_return(:lexis_nexis)
          end

          context 'when socure percent is configured at 100' do
            before do
              allow(IdentityConfig.store).to receive(:idv_address_vendor_socure_percent)
                .and_return(100)
              expect(Db::SpCost::AddSpCost).to receive(:call).with(
                service_provider,
                :socure_address,
                transaction_id: socure_phone_risk_result.transaction_id,
              )
            end

            it 'returns a socure hash result' do
              expect(subject.proof(applicant_pii:, current_sp: service_provider)).to eq(
                socure_phone_risk_result.to_h,
              )
            end
          end
        end
      end

      context 'when secondary address proofer is configured' do
        before do
          allow(IdentityConfig.store).to receive(:idv_address_secondary_vendor).and_return(:socure)
        end

        context 'when the primary vendor is different from the secondary' do
          before do
            allow(IdentityConfig.store).to receive(:idv_address_primary_vendor)
              .and_return(:lexis_nexis_ddp)
          end

          context 'when the primary proofing request is successful' do
            before do
              expect(Db::SpCost::AddSpCost).to receive(:call).with(
                service_provider,
                :lexis_nexis_address,
                transaction_id: ddp_phone_finder_result.transaction_id,
              )
            end

            it 'returns a lexis_nexis_ddp result hash' do
              expect(subject.proof(applicant_pii:, current_sp: service_provider)).to eq(
                ddp_phone_finder_result.to_h,
              )
            end
          end

          context 'when the primary proofing request fails' do
            let(:ddp_phone_finder_result) do
              Proofing::AddressResult.new(
                success: false,
                errors: [{ message: 'Unsuccessful result' }],
                exception: nil,
                vendor_name: 'lexisnexis:phone_finder_ddp',
                transaction_id: Faker::Internet.uuid,
              )
            end

            before do
              expect(Db::SpCost::AddSpCost).to receive(:call).with(
                service_provider,
                :lexis_nexis_address,
                transaction_id: ddp_phone_finder_result.transaction_id,
              )
              expect(Db::SpCost::AddSpCost).to receive(:call).with(
                service_provider,
                :socure_address,
                transaction_id: socure_phone_risk_result.transaction_id,
              )
            end

            it 'returns a results hash with both vendor checks' do
              expect(subject.proof(applicant_pii:, current_sp: service_provider)).to eq(
                socure_phone_risk_result.to_h.merge(alternate_result: ddp_phone_finder_result.to_h),
              )
            end
          end
        end

        context 'when the primary vendor is the same as the secondary' do
          before do
            allow(IdentityConfig.store).to receive(:idv_address_primary_vendor).and_return(:socure)
          end

          context 'when the primary proofing request is successful' do
            before do
              expect(Db::SpCost::AddSpCost).to receive(:call).with(
                service_provider,
                :socure_address,
                transaction_id: socure_phone_risk_result.transaction_id,
              )
            end

            it 'returns a socure result hash' do
              expect(subject.proof(applicant_pii:, current_sp: service_provider)).to eq(
                socure_phone_risk_result.to_h,
              )
            end
          end

          context 'when the primary proofing request fails' do
            let(:socure_phone_risk_result) do
              Proofing::AddressResult.new(
                success: false,
                errors: [{ message: 'Unsuccessful result' }],
                exception: nil,
                vendor_name: 'socure_phonerisk',
                transaction_id: Faker::Internet.uuid,
              )
            end

            before do
              expect(Db::SpCost::AddSpCost).to receive(:call).with(
                service_provider,
                :socure_address,
                transaction_id: socure_phone_risk_result.transaction_id,
              )
            end

            it 'returns a results hash' do
              expect(subject.proof(applicant_pii:, current_sp: service_provider)).to eq(
                socure_phone_risk_result.to_h,
              )
            end
          end
        end
      end
    end

    context 'when dual vendor check is enabled' do
      before do
        allow(FeatureManagement).to receive(:dual_vendor_check_enabled?).and_return(true)
        allow(IdentityConfig.store).to receive(:idv_address_vendor_socure_percent).and_return(0)
      end

      context 'when the primary vendor is lexis_nexis_ddp' do
        before do
          allow(IdentityConfig.store).to receive(:idv_address_primary_vendor)
            .and_return(:lexis_nexis_ddp)
        end

        context 'when the lexis_nexis_ddp proofing request is successful' do
          before do
            expect(Db::SpCost::AddSpCost).to receive(:call).with(
              service_provider,
              :lexis_nexis_address,
              transaction_id: ddp_phone_finder_result.transaction_id,
            )
          end

          it 'returns a lexis_nexis_ddp result hash' do
            expect(subject.proof(applicant_pii:, current_sp: service_provider)).to eq(
              ddp_phone_finder_result.to_h,
            )
          end
        end

        context 'when the lexis_nexis_ddp proofing request fails' do
          context 'when the response is dual vendor eligible' do
            let(:ddp_phone_finder_result) do
              Proofing::AddressResult.new(
                success: false,
                errors: [{ message: 'Unsuccessful result' }],
                exception: nil,
                vendor_name: 'lexisnexis:phone_finder_ddp',
                transaction_id: Faker::Internet.uuid,
                dual_vendor_check_eligible: true,
              )
            end

            context 'when traffic percentage threshold is met' do
              before do
                allow(IdentityConfig.store).to receive(
                  :idv_phone_verification_dual_vendor_check_ddp_lexis_nexis_percent,
                ).and_return(100)
                expect(Db::SpCost::AddSpCost).to receive(:call).with(
                  service_provider,
                  :lexis_nexis_address,
                  transaction_id: ddp_phone_finder_result.transaction_id,
                )
                expect(Db::SpCost::AddSpCost).to receive(:call).with(
                  service_provider,
                  :socure_address,
                  transaction_id: socure_phone_risk_result.transaction_id,
                )
              end

              it 'returns a results hash with both vendor checks' do
                expect(subject.proof(applicant_pii:, current_sp: service_provider)).to eq(
                  socure_phone_risk_result.to_h.merge(
                    alternate_result: ddp_phone_finder_result.to_h,
                  ),
                )
              end
            end

            context 'when traffic percentage threshold is not met' do
              before do
                allow(IdentityConfig.store).to receive(
                  :idv_phone_verification_dual_vendor_check_ddp_lexis_nexis_percent,
                ).and_return(0)
                expect(Db::SpCost::AddSpCost).to receive(:call).with(
                  service_provider,
                  :lexis_nexis_address,
                  transaction_id: ddp_phone_finder_result.transaction_id,
                )
              end

              it 'returns a ddp_lexis_nexis results hash' do
                expect(subject.proof(applicant_pii:, current_sp: service_provider)).to eq(
                  ddp_phone_finder_result.to_h,
                )
              end
            end
          end

          context 'when the response is not dual vendor eligible' do
            let(:ddp_phone_finder_result) do
              Proofing::AddressResult.new(
                success: false,
                errors: [{ message: 'Unsuccessful result' }],
                exception: nil,
                vendor_name: 'lexisnexis:phone_finder_ddp',
                transaction_id: Faker::Internet.uuid,
              )
            end

            before do
              expect(Db::SpCost::AddSpCost).to receive(:call).with(
                service_provider,
                :lexis_nexis_address,
                transaction_id: ddp_phone_finder_result.transaction_id,
              )
            end

            it 'returns a lexis_nexis_ddp results hash' do
              expect(subject.proof(applicant_pii:, current_sp: service_provider)).to eq(
                ddp_phone_finder_result.to_h,
              )
            end
          end
        end
      end

      context 'when the primary vendor is socure' do
        before do
          allow(IdentityConfig.store).to receive(:idv_address_primary_vendor).and_return(:socure)
        end

        context 'when the socure proofing request is successful' do
          before do
            expect(Db::SpCost::AddSpCost).to receive(:call).with(
              service_provider,
              :socure_address,
              transaction_id: socure_phone_risk_result.transaction_id,
            )
          end

          it 'returns a socure result hash' do
            expect(subject.proof(applicant_pii:, current_sp: service_provider)).to eq(
              socure_phone_risk_result.to_h,
            )
          end
        end

        context 'when the socure proofing request fails' do
          context 'when the response is dual vendor eligible' do
            let(:socure_phone_risk_result) do
              Proofing::AddressResult.new(
                success: false,
                errors: [{ message: 'Unsuccessful result' }],
                exception: nil,
                vendor_name: 'socure_phonerisk',
                transaction_id: Faker::Internet.uuid,
                dual_vendor_check_eligible: true,
              )
            end

            context 'when traffic percentage threshold is met' do
              before do
                allow(IdentityConfig.store).to receive(
                  :idv_phone_verification_dual_vendor_check_socure_percent,
                ).and_return(100)
                expect(Db::SpCost::AddSpCost).to receive(:call).with(
                  service_provider,
                  :socure_address,
                  transaction_id: socure_phone_risk_result.transaction_id,
                )
                expect(Db::SpCost::AddSpCost).to receive(:call).with(
                  service_provider,
                  :lexis_nexis_address,
                  transaction_id: ddp_phone_finder_result.transaction_id,
                )
              end

              it 'returns a results hash with both vendor checks' do
                expect(subject.proof(applicant_pii:, current_sp: service_provider)).to eq(
                  ddp_phone_finder_result.to_h.merge(
                    alternate_result: socure_phone_risk_result.to_h,
                  ),
                )
              end
            end

            context 'when traffic percentage threshold is not met' do
              before do
                allow(IdentityConfig.store).to receive(
                  :idv_phone_verification_dual_vendor_check_socure_percent,
                ).and_return(0)
                expect(Db::SpCost::AddSpCost).to receive(:call).with(
                  service_provider,
                  :socure_address,
                  transaction_id: socure_phone_risk_result.transaction_id,
                )
              end

              it 'returns a socure_phone_risk_result results hash' do
                expect(subject.proof(applicant_pii:, current_sp: service_provider)).to eq(
                  socure_phone_risk_result.to_h,
                )
              end
            end
          end

          context 'when the response is not dual vendor eligible' do
            let(:socure_phone_risk_result) do
              Proofing::AddressResult.new(
                success: false,
                errors: [{ message: 'Unsuccessful result' }],
                exception: nil,
                vendor_name: 'socure_phonerisk',
                transaction_id: Faker::Internet.uuid,
              )
            end

            before do
              expect(Db::SpCost::AddSpCost).to receive(:call).with(
                service_provider,
                :socure_address,
                transaction_id: socure_phone_risk_result.transaction_id,
              )
            end

            it 'returns a socure_phonerisk results hash' do
              expect(subject.proof(applicant_pii:, current_sp: service_provider)).to eq(
                socure_phone_risk_result.to_h,
              )
            end
          end
        end
      end
    end

    context 'when the configured vendor does not have a proofer' do
      before do
        allow(IdentityConfig.store).to receive(:idv_address_primary_vendor)
          .and_return(:unknown_vendor)
      end

      it 'throws an InvalidAddressVendorError' do
        expect { subject.proof(applicant_pii:, current_sp: service_provider) }.to raise_error(
          Proofing::AddressProofer::InvalidAddressVendorError,
        )
      end
    end
  end
end
