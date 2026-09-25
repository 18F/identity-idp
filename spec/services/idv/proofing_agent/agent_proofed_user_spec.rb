# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Idv::ProofingAgent::AgentProofedUser do
  let(:id) { SecureRandom.uuid }
  let(:success) { true }
  let(:pii) { { 'first_name' => 'Testy', 'last_name' => 'Testerson' } }

  context 'EncryptedRedisStructStorage' do
    it 'works with EncryptedRedisStructStorage' do
      result = Idv::ProofingAgent::AgentProofedUser.new(
        id:,
        success:,
        pii:,
      )
      EncryptedRedisStructStorage.store(result)
      loaded_result = EncryptedRedisStructStorage.load(
        id,
        type: Idv::ProofingAgent::AgentProofedUser,
      )

      expect(loaded_result).to have_attributes(
        id:,
        success:,
        pii: pii.deep_symbolize_keys,
        aamva_status: nil,
      )
    end

    it 'persists mrz_status with EncryptedRedisStructStorage' do
      result = Idv::ProofingAgent::AgentProofedUser.new(
        id:,
        success:,
        mrz_status: :pass,
        pii:,
      )
      EncryptedRedisStructStorage.store(result)
      loaded_result = EncryptedRedisStructStorage.load(
        id,
        type: Idv::ProofingAgent::AgentProofedUser,
      )

      expect(loaded_result.mrz_status).to eq(:pass)
    end

    describe '#mrz_status' do
      it 'returns a symbol when present' do
        result = Idv::ProofingAgent::AgentProofedUser.new(
          id:,
          success:,
          pii:,
          mrz_status: 'pass',
        )
        expect(result.mrz_status).to eq(:pass)
      end

      it 'returns nil when not present' do
        result = Idv::ProofingAgent::AgentProofedUser.new(
          id:,
          success:,
          pii:,
        )
        expect(result.mrz_status).to be_nil
      end
    end

    describe '#aamva_status' do
      let(:agent_proofed_user) { Idv::ProofingAgent::AgentProofedUser.new(aamva_status: status) }
      subject { agent_proofed_user.aamva_status }

      context 'when aamva status is present' do
        let(:status) { :passed }

        it 'returns a symbol' do
          is_expected.to be(status)
        end
      end

      context 'when aamva status is nil' do
        let(:status) { nil }

        it 'returns nil' do
          is_expected.to be_nil
        end
      end
    end

    describe '#source_check_vendor' do
      let(:vendor) { 'aamva:state_id' }
      let(:agent_proofed_user) do
        Idv::ProofingAgent::AgentProofedUser.new(source_check_vendor: vendor)
      end

      it 'returns the stored source_check_vendor' do
        expect(agent_proofed_user.source_check_vendor).to eq(vendor)
      end
    end

    describe '#document_type_received' do
      let(:document_type_received) { 'drivers_license' }
      let(:agent_proofed_user) do
        Idv::ProofingAgent::AgentProofedUser.new(pii: { document_type_received: })
      end

      it 'returns the stored pii document_type_received' do
        expect(agent_proofed_user.document_type_received).to eq(document_type_received)
      end
    end

    describe '#resolution_vendor' do
      let(:vendor) { 'lexisnexis:instant_verify_ddp' }
      let(:agent_proofed_user) do
        Idv::ProofingAgent::AgentProofedUser.new(
          resolution: { context: { stages: { resolution: { vendor_name: vendor } } } },
        )
      end

      it 'returns the stored resolution vendor' do
        expect(agent_proofed_user.resolution_vendor).to eq(vendor)
      end

      context 'when resolution result is nil' do
        let(:agent_proofed_user) { Idv::ProofingAgent::AgentProofedUser.new }

        it 'returns nil' do
          expect(agent_proofed_user.resolution_vendor).to be_nil
        end
      end
    end

    describe '#residential_resolution_vendor' do
      let(:vendor) { 'lexisnexis:instant_verify_ddp' }
      let(:agent_proofed_user) do
        Idv::ProofingAgent::AgentProofedUser.new(
          resolution: { context: { stages: { residential_address: { vendor_name: vendor } } } },
        )
      end

      it 'returns the stored residential resolution vendor' do
        expect(agent_proofed_user.residential_resolution_vendor).to eq(vendor)
      end

      context 'when resolution result is nil' do
        let(:agent_proofed_user) { Idv::ProofingAgent::AgentProofedUser.new }

        it 'returns nil' do
          expect(agent_proofed_user.residential_resolution_vendor).to be_nil
        end
      end
    end

    describe '#phone_precheck_vendor' do
      let(:vendor) { 'socure_phonerisk' }
      let(:agent_proofed_user) do
        Idv::ProofingAgent::AgentProofedUser.new(
          resolution: { context: { stages: { phone_precheck: { vendor_name: vendor } } } },
        )
      end

      it 'returns the stored phone precheck vendor' do
        expect(agent_proofed_user.phone_precheck_vendor).to eq(vendor)
      end

      context 'when resolution result is nil' do
        let(:agent_proofed_user) { Idv::ProofingAgent::AgentProofedUser.new }

        it 'returns nil' do
          expect(agent_proofed_user.phone_precheck_vendor).to be_nil
        end
      end
    end

    describe '#phone_precheck_successful?' do
      context 'when resolution has a phone_precheck result' do
        let(:agent_proofed_user) do
          Idv::ProofingAgent::AgentProofedUser.new(
            resolution: { context: { stages: { phone_precheck: { success: } } } },
          )
        end

        context 'when the phone_precheck success value is true' do
          let(:success) { true }

          it 'returns true' do
            expect(agent_proofed_user.phone_precheck_successful?).to be(true)
          end
        end

        context 'when the phone_precheck success value is false' do
          let(:success) { false }

          it 'returns true' do
            expect(agent_proofed_user.phone_precheck_successful?).to be(false)
          end
        end
      end

      context 'when resolution result is nil' do
        let(:agent_proofed_user) { Idv::ProofingAgent::AgentProofedUser.new }

        it 'returns false' do
          expect(agent_proofed_user.phone_precheck_successful?).to eq(false)
        end
      end
    end
  end
end
