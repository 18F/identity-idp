require 'rails_helper'
require 'ostruct'

describe Idv::Agent do
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

    describe '#proof_resolution' do
      context 'proofing state_id enabled' do
        it 'does not proof state_id if resolution fails' do
          agent = Idv::Agent.new({ ssn: '444-55-6666', first_name: Faker::Name.first_name,
                                   zipcode: '11111' })
          result = agent.proof_resolution(should_proof_state_id: true)
          expect(result[:errors][:ssn]).to eq ['Unverified SSN.']
          expect(result[:context][:stages]).to_not include({ state_id: 'StateIdMock' })
        end

        it 'does proof state_id if resolution succeeds' do
          agent = Idv::Agent.new({ ssn: '444-55-8888', first_name: Faker::Name.first_name,
                                   zipcode: '11111' })
          result = agent.proof_resolution(should_proof_state_id: true)
          expect(result[:context][:stages]).to include({ state_id: 'StateIdMock' })
        end
      end

      context 'proofing state_id disabled' do
        it 'does not proof state_id if resolution fails' do
          agent = Idv::Agent.new({ ssn: '444-55-6666', first_name: Faker::Name.first_name,
                                   zipcode: '11111' })
          result = agent.proof_resolution(should_proof_state_id: false)
          expect(result[:errors][:ssn]).to eq ['Unverified SSN.']
          expect(result[:context][:stages]).to_not include({ state_id: 'StateIdMock' })
        end

        it 'does not proof state_id if resolution succeeds' do
          agent = Idv::Agent.new({ ssn: '444-55-8888', first_name: Faker::Name.first_name,
                                   zipcode: '11111' })
          result = agent.proof_resolution(should_proof_state_id: false)
          expect(result[:context][:stages]).to_not include({ state_id: 'StateIdMock' })
        end
      end

      it 'returns an unsuccessful result and notifies exception trackers if an exception occurs' do
        exception = Proofer::TimeoutError

        agent = Idv::Agent.new(ssn: '444-55-8888', first_name: 'Time Exception',
                               zipcode: '11111')

        expect(NewRelic::Agent).to receive(:notice_error).with(exception)
        expect(ExceptionNotifier).to receive(:notify_exception).with(exception)

        result = agent.proof_resolution(should_proof_state_id: false)

        expect(result[:exception]).to be_instance_of(exception)
        expect(result).to include(
          success: false,
          timed_out: true,
        )
      end
    end

    describe '#proof_address' do
      let(:document_capture_session) { DocumentCaptureSession.new(result_id: 'abc123') }

      it 'proofs addresses successfully with valid information' do
        agent = Idv::Agent.new({ phone: Faker::PhoneNumber.cell_phone })
        result = agent.proof_address(document_capture_session)
        expect(result[:context][:stages]).to include({ address: 'AddressMock' })
        expect(result[:success]).to eq true
      end

      it 'fails to proof addresses with invalid information' do
        agent = Idv::Agent.new({ phone: '7035555555' })
        result = agent.proof_address(document_capture_session)
        expect(result[:context][:stages]).to include({ address: 'AddressMock' })
        expect(result[:success]).to eq false
      end
    end
  end
end
