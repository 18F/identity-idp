require 'rails_helper'

describe Idv::ProoferJob do
  describe '#perform' do
    context 'without mocking the agent' do
      let(:result_id) { SecureRandom.uuid }
      let(:applicant) { { first_name: 'Jean-Luc', ssn: '123456789', zipcode: '11111' } }
      let(:stages) { %i[resolution] }

      it 'works' do
        Idv::ProoferJob.perform_now(
          result_id: result_id,
          applicant_json: applicant.to_json,
          stages: stages.to_json
        )

        result = VendorValidatorResultStorage.new.load(result_id)

        expect(result.success?).to eq(true)
        expect(result.timed_out?).to eq(false)
        expect(result.job_failed?).to eq(false)
        expect(result.messages).to be_empty
        expect(result.errors).to be_empty
      end
    end

    context 'when mocking the agent' do
      let(:result_id) { SecureRandom.uuid }
      let(:applicant) { { first_name: 'Jean-Luc', last_name: 'Picard' } }
      let(:stages) { %i[phone] }
      let(:agent) { instance_double(Idv::Agent) }
      let(:proofer_results) { {} }

      before do
        allow(agent).to receive(:proof).and_return(proofer_results)
        allow(Idv::Agent).to receive(:new).and_return(agent)
      end

      subject do
        Idv::ProoferJob.perform_now(
          result_id: result_id,
          applicant_json: applicant.to_json,
          stages: stages.to_json
        )
      end

      shared_examples 'a proofer job' do
        it 'uses the Idv::Agent' do
          subject

          expect(Idv::Agent).to have_received(:new).with(applicant)
          expect(agent).to have_received(:proof).with(*stages)
        end
      end

      context 'when verification succeeds' do
        let(:proofer_results) { { success: true, messages: ['a reason'] } }

        it_behaves_like 'a proofer job'

        it 'should save a successful result' do
          subject

          result = VendorValidatorResultStorage.new.load(result_id)

          expect(result.success?).to eq(true)
          expect(result.timed_out?).to eq(false)
          expect(result.job_failed?).to eq(false)
          expect(result.messages).to eq(['a reason'])
          expect(result.errors).to be_empty
        end
      end

      context 'when verification fails' do
        let(:proofer_results) do
          {
            success: false,
            messages: ['Bad number'],
            errors: { phone: 'The phone number could not be verified.' },
          }
        end

        it_behaves_like 'a proofer job'

        it 'should save an unsuccessful result' do
          subject

          result = VendorValidatorResultStorage.new.load(result_id)

          expect(result.success?).to eq(false)
          expect(result.timed_out?).to eq(false)
          expect(result.job_failed?).to eq(false)
          expect(result.messages).to eq(['Bad number'])
          expect(result.errors).to eq(phone: 'The phone number could not be verified.')
        end
      end

      context 'when the idv agent raises' do
        before do
          allow(agent).to receive(:proof).and_raise(RuntimeError, '🔥🔥🔥')
        end

        it 'should rescue from errors and save a failed job result' do
          expect { subject }.to raise_error(RuntimeError, '🔥🔥🔥')

          result = VendorValidatorResultStorage.new.load(result_id)

          expect(result.success?).to eq(false)
          expect(result.timed_out?).to eq(false)
          expect(result.job_failed?).to eq(true)
        end
      end
    end
  end
end
