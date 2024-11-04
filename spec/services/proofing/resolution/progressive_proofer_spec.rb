require 'rails_helper'

RSpec.describe Proofing::Resolution::ProgressiveProofer do
  let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN }
  let(:ipp_enrollment_in_progress) { false }
  let(:request_ip) { Faker::Internet.ip_v4_address }
  let(:threatmetrix_session_id) { SecureRandom.uuid }
  let(:user_email) { Faker::Internet.email }
  let(:current_sp) { build(:service_provider) }

  let(:instant_verify_result) do
    Proofing::Resolution::Result.new(
      success: true,
      attributes_requiring_additional_verification: [:address],
      transaction_id: 'ln-123',
    )
  end

  let(:instant_verify_proofer) do
    instance_double(
      Proofing::LexisNexis::InstantVerify::Proofer,
      proof: instant_verify_result,
    )
  end

  let(:aamva_plugin) { Proofing::Resolution::Plugins::AamvaPlugin.new }

  let(:aamva_result) do
    Proofing::StateIdResult.new(
      success: false,
      transaction_id: 'aamva-123',
    )
  end

  let(:aamva_proofer) { instance_double(Proofing::Aamva::Proofer, proof: aamva_result) }

  let(:threatmetrix_plugin) do
    Proofing::Resolution::Plugins::ThreatMetrixPlugin.new
  end

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

  let(:dcs_uuid) { SecureRandom.uuid }

  subject(:progressive_proofer) { described_class.new }

  let(:state_id_address) do
    {
      address1: applicant_pii[:identity_doc_address1],
      address2: applicant_pii[:identity_doc_address2],
      city: applicant_pii[:identity_doc_city],
      state: applicant_pii[:identity_doc_address_state],
      zipcode: applicant_pii[:identity_doc_zipcode],
    }
  end

  let(:residential_address) do
    {
      address1: applicant_pii[:address1],
      address2: applicant_pii[:address2],
      city: applicant_pii[:city],
      state: applicant_pii[:state],
      zipcode: applicant_pii[:zipcode],
    }
  end

  let(:transformed_pii) do
    {
      first_name: 'FAKEY',
      last_name: 'MCFAKERSON',
      dob: '1938-10-06',
      address1: '123 Way St',
      address2: '2nd Address Line',
      city: 'Best City',
      zipcode: '12345',
      state_id_jurisdiction: 'VA',
      address_state: 'VA',
      state_id_number: '1111111111111',
      same_address_as_id: 'true',
    }
  end

  let(:resolution_result) do
    instance_double(Proofing::Resolution::Result, success?: true, errors: nil)
  end

  def block_real_instant_verify_requests
    allow(Proofing::LexisNexis::InstantVerify::VerificationRequest).to receive(:new)
  end

  before do
    allow(progressive_proofer).to receive(:threatmetrix_plugin).and_return(threatmetrix_plugin)
    allow(threatmetrix_plugin).to receive(:proofer).and_return(threatmetrix_proofer)

    allow(progressive_proofer).to receive(:aamva_plugin).and_return(aamva_plugin)
    allow(aamva_plugin).to receive(:proofer).and_return(aamva_proofer)

    allow(progressive_proofer).to receive(:resolution_proofer).and_return(instant_verify_proofer)

    block_real_instant_verify_requests
  end

  it 'assigns aamva_plugin' do
    expect(described_class.new.aamva_plugin).to be_a(
      Proofing::Resolution::Plugins::AamvaPlugin,
    )
  end

  it 'assigns threatmetrix_plugin' do
    expect(described_class.new.threatmetrix_plugin).to be_a(
      Proofing::Resolution::Plugins::ThreatMetrixPlugin,
    )
  end

  describe '#proof' do
    before do
      allow(IdentityConfig.store).to receive(:proofer_mock_fallback).and_return(false)
    end

    subject(:proof) do
      progressive_proofer.proof(
        applicant_pii:,
        ipp_enrollment_in_progress:,
        request_ip:,
        threatmetrix_session_id:,
        timer: JobHelpers::Timer.new,
        user_email:,
        current_sp:,
      )
    end

    context 'remote unsupervised proofing' do
      it 'calls AamvaPlugin' do
        expect(aamva_plugin).to receive(:call).with(
          applicant_pii:,
          current_sp:,
          instant_verify_result:,
          ipp_enrollment_in_progress: false,
          timer: an_instance_of(JobHelpers::Timer),
        )
        proof
      end

      it 'calls ThreatMetrixPlugin' do
        expect(threatmetrix_plugin).to receive(:call).with(
          applicant_pii:,
          current_sp:,
          request_ip:,
          threatmetrix_session_id:,
          timer: an_instance_of(JobHelpers::Timer),
          user_email:,
        )
        proof
      end

      it 'returns a ResultAdjudicator' do
        proof.tap do |result|
          expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)

          expect(result.resolution_result).to eql(instant_verify_result)
          expect(result.state_id_result).to eql(aamva_result)
          expect(result.device_profiling_result).to eql(threatmetrix_result)
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

        it 'calls AamvaPlugin' do
          expect(aamva_plugin).to receive(:call).with(
            applicant_pii:,
            current_sp:,
            instant_verify_result: instant_verify_result,
            ipp_enrollment_in_progress: true,
            timer: an_instance_of(JobHelpers::Timer),
          )

          proof
        end

        it 'calls ThreatMetrixPlugin' do
          expect(threatmetrix_plugin).to receive(:call).with(
            applicant_pii:,
            current_sp:,
            request_ip:,
            threatmetrix_session_id:,
            timer: an_instance_of(JobHelpers::Timer),
            user_email:,
          )
          proof
        end

        it 'returns a ResultAdjudicator' do
          proof.tap do |result|
            expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)

            expect(result.resolution_result).to eql(instant_verify_result)
            expect(result.state_id_result).to eql(aamva_result)
            expect(result.device_profiling_result).to eql(threatmetrix_result)
            expect(result.residential_resolution_result).to eql(instant_verify_result)
            expect(result.ipp_enrollment_in_progress).to eql(true)
            expect(proof.same_address_as_id).to eq(applicant_pii[:same_address_as_id])
          end
        end
      end

      context 'residential address is different than id' do
        let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS }

        let(:instant_verify_residential_result) do
          Proofing::Resolution::Result.new(
            success: true,
            vendor_name: 'lexis_nexis_residential',
          )
        end

        before do
          allow(instant_verify_proofer).to receive(:proof).
            and_return(instant_verify_residential_result, instant_verify_result)
        end

        it 'calls ThreatMetrixPlugin' do
          expect(threatmetrix_plugin).to receive(:call).with(
            applicant_pii:,
            current_sp:,
            request_ip:,
            threatmetrix_session_id:,
            timer: an_instance_of(JobHelpers::Timer),
            user_email:,
          )
          proof
        end

        it 'calls AamvaPlugin' do
          expect(aamva_plugin).to receive(:call).with(
            applicant_pii:,
            current_sp:,
            instant_verify_result:,
            ipp_enrollment_in_progress: true,
            timer: an_instance_of(JobHelpers::Timer),
          ).and_call_original
          proof
        end

        it 'returns a ResultAdjudicator' do
          proof.tap do |result|
            expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)
            expect(result.resolution_result).to eql(instant_verify_result)
            expect(result.state_id_result).to eql(aamva_result)
            expect(result.device_profiling_result).to eql(threatmetrix_result)
            expect(result.residential_resolution_result).to eql(instant_verify_residential_result)
            expect(result.ipp_enrollment_in_progress).to eql(true)
            expect(result.same_address_as_id).to eql('false')
          end
        end
      end
    end

    context 'ipp flow' do
      let(:ipp_enrollment_in_progress) { true }
      let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID }

      context 'residential address and id address are the same' do
        it 'only makes one request to LexisNexis InstantVerify' do
          proof

          expect(instant_verify_proofer).to have_received(:proof).exactly(:once)
          expect(aamva_proofer).to have_received(:proof)
        end

        it 'produces a result adjudicator with correct information' do
          expect(proof.same_address_as_id).to eq('true')
          expect(proof.ipp_enrollment_in_progress).to eq(true)
          expect(proof.resolution_result).to eq(proof.residential_resolution_result)
          expect(aamva_proofer).to have_received(:proof)
        end

        it 'uses the transformed PII' do
          allow(progressive_proofer).to receive(:with_state_id_address).and_return(transformed_pii)

          expect(proof.same_address_as_id).to eq('true')
          expect(proof.ipp_enrollment_in_progress).to eq(true)
          expect(proof.resolution_result).to eq(proof.residential_resolution_result)
          expect(proof.resolution_result.success?).to eq(true)
        end

        it 'records a single LexisNexis SP cost' do
          proof

          lexis_nexis_sp_costs = SpCost.where(
            cost_type: :lexis_nexis_resolution,
            issuer: current_sp.issuer,
          )

          expect(lexis_nexis_sp_costs.count).to eq(1)
        end

        context 'LexisNexis InstantVerify fails' do
          let(:instant_verify_proofing_success) { false }

          before do
            allow(instant_verify_result).to(
              receive(
                :failed_result_can_pass_with_additional_verification?,
              ).and_return(true),
            )
          end

          it 'includes the state ID in the InstantVerify call' do
            expect(instant_verify_proofer).to receive(:proof).
              with(hash_including(state_id_address))

            proof
          end
        end
      end

      context 'residential address and id address are different' do
        let(:residential_address_proof) do
          instance_double(Proofing::Resolution::Result, transaction_id: 'residential-123')
        end

        let(:ipp_enrollment_in_progress) { true }
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
          let(:instant_verify_result) { residential_address_proof }

          before do
            allow(residential_address_proof).to receive(:success?).and_return(true)
          end

          context 'LexisNexis InstantVerify passes for id address' do
            it 'makes two requests to the InstantVerify Proofer' do
              proof

              expect(instant_verify_proofer).to have_received(:proof).
                with(hash_including(residential_address)).
                ordered
              expect(instant_verify_proofer).to have_received(:proof).
                with(hash_including(state_id_address)).
                ordered
            end

            it 'records 2 LexisNexis SP cost' do
              proof

              lexis_nexis_sp_costs = SpCost.where(
                cost_type: :lexis_nexis_resolution,
                issuer: current_sp.issuer,
              )

              expect(lexis_nexis_sp_costs.count).to eq(2)
            end
          end
        end
      end
    end
  end
end
