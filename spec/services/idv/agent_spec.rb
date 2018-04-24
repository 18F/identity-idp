require 'rails_helper'
require 'ostruct'

describe Idv::Agent do
  describe '.proofer_attribute?' do
    it 'returns whether the attribute is available in Proofer::Applicant' do
      key = 'foobarbaz'
      expect(Proofer::Applicant).to receive(:method_defined?).with(key)
      Idv::Agent.proofer_attribute?(key)
    end
  end

  describe 'instance' do

    let(:applicant) { { } }

    let(:agent) { Idv::Agent.new(applicant) }

    describe '#get_agent' do
      let(:vendor_key) { :some_vendor_key }
      let(:vendor) { 'some_vendor' }
      let(:foo) { double }

      it 'returns a new Proofer::Agent with the correct data' do
        allow(Figaro.env).to receive(vendor_key).and_return(vendor)
        expect(Proofer::Agent).to receive(:new).with(
          applicant: agent.instance_variable_get(:@applicant),
          vendor: vendor.to_sym,
          kbv: false
        ).and_return(foo)

        result = agent.send(:get_agent, vendor_key)

        expect(result).to eq(foo)
      end
    end

    describe '#merge_results' do
      let(:orig_results) do
        {
          errors: { foo: 'bar', bar: 'baz' },
          normalized_applicant: {},
          reasons: ['reason 1'],
          success: true,
        }
      end

      let(:new_result) do
        Proofer::Resolution.new(
          vendor_resp: OpenStruct.new(
            normalized_applicant: { first_name: 'Homer' },
            reasons: ['reason 2']
          ),
          errors: { foo: 'blarg', baz: 'foo' },
          success: false,
        )
      end

      let(:merged_results) { agent.send(:merge_results, orig_results, new_result) }

      it 'merges errors' do
        expect(merged_results[:errors]).to eq(orig_results[:errors].merge(new_result.errors))
      end

      it 'concatenates reasons' do
        expect(merged_results[:reasons]).to eq(orig_results[:reasons] + new_result.vendor_resp.reasons)
      end

      it 'merges normalized applicant' do
        expect(merged_results[:normalized_applicant]).to eq(new_result.vendor_resp.normalized_applicant)
      end

      it 'keeps the last success' do
        expect(merged_results[:success]).to eq(false)
      end
    end

    describe '#proof_one' do
      let(:applicant) { { phone: '1112223333', state: 'WA' } }

      before do
        proofer_agent = instance_double('Proofer::Agent')
        expect(proofer_agent).to receive(method).with(data)
        expect(agent).to receive(:get_agent).with(vendor_key).and_return(proofer_agent)
      end

      context ':phone stage' do
        let(:stage) { :phone }
        let(:method) { :submit_phone }
        let(:vendor_key) { :phone_proofing_vendor }
        let(:data) { applicant[:phone] }

        it 'gets the agent for the `:phone_proofing_vendor` and calls `submit_phone`' do
          agent.proof_one(stage)
        end
      end

      context ':profile stage' do
        let(:stage) { :profile }
        let(:method) { :start }
        let(:vendor_key) { :profile_proofing_vendor }
        let(:data) { applicant }

        it 'gets the agent for the `:profile_proofing_vendor` and calls `start`' do
          agent.proof_one(stage)
        end
      end

      context ':state_id stage' do
        let(:stage) { :state_id }
        let(:method) { :submit_state_id }
        let(:vendor_key) { :state_id_proofing_vendor }
        let(:data) { applicant.merge(state_id_jurisdiction: applicant[:state]) }

        it 'gets the agent for the `:state_id_proofing_vendor` and calls `submit_state_id`' do
          agent.proof_one(stage)
        end
      end
    end

    describe '#proof' do
      let(:profile_resolution) do
        Proofer::Resolution.new(
          vendor_resp: OpenStruct.new(
            normalized_applicant: { first_name: 'Homer' },
            reasons: ['reason 1']
          ),
          success: true
        )
      end
      let(:state_id_resolution) do
        Proofer::Resolution.new(
          vendor_resp: OpenStruct.new(
            normalized_applicant: { },
            reasons: ['reason 2']
          ),
          success: true
        )
      end
      let(:failed_resolution) do
        Proofer::Resolution.new(
          vendor_resp: OpenStruct.new(
            normalized_applicant: { },
            reasons: ['bah humbug']
          ),
          success: false,
          errors: {
            bad: 'stuff'
          }
        )
      end

      before do
        allow(agent).to receive(:proof_one) do |stage|
          case stage
          when :profile
            profile_resolution
          when :state_id
            state_id_resolution
          when :failed
            failed_resolution
          end
        end
      end

      context 'when all stages succeed' do

        let(:stages) { [:profile, :state_id] }

        it 'calls #proof_one for each stage and returns merged results' do
          stages.each do |stage|
            expect(agent).to receive(:proof_one).with(stage)
          end

          results = agent.proof(*stages)

          expect(results).to eq({
            errors: {},
            normalized_applicant: profile_resolution.vendor_resp.normalized_applicant,
            reasons: profile_resolution.vendor_resp.reasons + state_id_resolution.vendor_resp.reasons,
            success: true
          })
        end
      end

      context 'when the fist stage fails' do
        let(:stages) { [:failed, :state_id] }

        it 'calls #proof_one only for the first stage and returns merged results' do
          expect(agent).to receive(:proof_one).with(stages.first)
          expect(agent).not_to receive(:proof_one).with(stages.second)

          results = agent.proof(*stages)

          expect(results).to eq({
            errors: failed_resolution.errors,
            normalized_applicant: {},
            reasons: failed_resolution.vendor_resp.reasons,
            success: false
          })
        end
      end
    end
  end
end
