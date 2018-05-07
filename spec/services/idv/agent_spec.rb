require 'rails_helper'
require 'ostruct'

describe Idv::Agent do
  describe '.proofer_attribute?' do
    it 'returns whether the attribute is available in Idv::Proofer::ATTRIBUTES' do
      key = :foobarbaz
      expect(Idv::Proofer).to receive(:attribute?).with(key)
      Idv::Agent.proofer_attribute?(key)
    end
  end

  describe 'instance' do
    let(:applicant) { { foo: 'bar' } }

    let(:agent) { Idv::Agent.new(applicant) }

    describe '#merge_results' do
      let(:orig_results) do
        {
          errors: { foo: 'bar', bar: 'baz' },
          messages: ['reason 1'],
          success: true,
          exception: StandardError.new,
        }
      end

      let(:new_result) do
        {
          errors: { foo: 'blarg', baz: 'foo' },
          messages: ['reason 2'],
          success: false,
          exception: StandardError.new,
        }
      end

      let(:merged_results) { agent.send(:merge_results, orig_results, new_result) }

      it 'keeps the last errors' do
        expect(merged_results[:errors]).to eq(new_result[:errors])
      end

      it 'concatenates messages' do
        expect(merged_results[:messages]).to eq(orig_results[:messages] + new_result[:messages])
      end

      it 'keeps the last success' do
        expect(merged_results[:success]).to eq(false)
      end

      it 'keeps the last exception' do
        expect(merged_results[:exception]).to eq(new_result[:exception])
      end
    end

    describe '#proof' do
      let(:resolution_message) { 'reason 1' }
      let(:state_id_message) { 'reason 2' }
      let(:failed_message) { 'bah humbug' }
      let(:error) { { bad: 'stuff' } }

      subject { agent.proof(*stages) }

      before do
        allow(Idv::Proofer).to receive(:get_vendor) do |stage|
          logic = case stage
                  when :resolution
                    proc { |_, r| r.add_message('reason 1') }
                  when :state_id
                    proc { |_, r| r.add_message('reason 2') }
                  when :failed
                    proc { |_, r| r.add_message('bah humbug').add_error(:bad, 'stuff') }
                  end
          Class.new(Proofer::Base) do
            attributes(:foo)
            proof(&logic)
          end
        end
      end

      context 'when all stages succeed' do
        let(:stages) { %i[resolution state_id] }

        it 'results from all stages are included' do
          expect(subject.to_h).to eq(
            errors: {},
            messages: [resolution_message, state_id_message],
            success: true,
            exception: nil,
          )
        end
      end

      context 'when the fist stage fails' do
        let(:stages) { %i[failed state_id] }

        it 'only the results from the first stage are included' do
          expect(subject.to_h).to eq(
            errors: { bad: ['stuff'] },
            messages: [failed_message],
            success: false,
            exception: nil,
          )
        end
      end
    end
  end
end
