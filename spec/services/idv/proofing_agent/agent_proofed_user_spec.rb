# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Idv::ProofingAgent::AgentProofedUser do
  let(:id) { SecureRandom.uuid }
  let(:doc_auth_success) { true }
  let(:pii) { { 'first_name' => 'Testy', 'last_name' => 'Testerson' } }

  context 'EncryptedRedisStructStorage' do
    it 'works with EncryptedRedisStructStorage' do
      result = Idv::ProofingAgent::AgentProofedUser.new(
        id:,
        doc_auth_success:,
        pii:,
      )
      EncryptedRedisStructStorage.store(result)
      loaded_result = EncryptedRedisStructStorage.load(
        id,
        type: Idv::ProofingAgent::AgentProofedUser,
      )

      expect(loaded_result).to have_attributes(
        id:,
        doc_auth_success:,
        pii: pii.deep_symbolize_keys,
        aamva_status: nil,
      )
    end

    it 'persists mrz_status with EncryptedRedisStructStorage' do
      result = Idv::ProofingAgent::AgentProofedUser.new(
        id:,
        doc_auth_success:,
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
          doc_auth_success:,
          pii:,
          mrz_status: 'pass',
        )
        expect(result.mrz_status).to eq(:pass)
      end

      it 'returns nil when not present' do
        result = Idv::ProofingAgent::AgentProofedUser.new(
          id:,
          doc_auth_success:,
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

    describe '#success?' do
      let(:aamva_status) { nil }
      let(:mrz_status) { nil }
      let(:result) do
        Idv::ProofingAgent::AgentProofedUser.new(
          id: id,
          doc_auth_success: true,
          pii: nil,
          aamva_status:,
          mrz_status:,
        )
      end

      context 'doc_auth_success is true, and aamva passed' do
        let(:aamva_status) { 'passed' }

        it 'returns true' do
          expect(result.success?).to eq(true)
        end
      end

      context 'doc_auth_success is true, and mrz passed' do
        let(:mrz_status) { 'pass' }

        it 'returns true' do
          expect(result.success?).to eq(true)
        end
      end

      context 'doc_auth_success is true, but aamva failed' do
        let(:aamva_status) { 'failed' }

        it 'returns false' do
          expect(result.success?).to eq(false)
        end
      end

      context 'doc_auth_success is true, but mrz failed' do
        let(:mrz_status) { 'failed' }

        it 'returns false' do
          expect(result.success?).to eq(false)
        end
      end
    end
  end
end
