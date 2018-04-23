require 'rails_helper'

describe Idv::ProoferJob do
  def mock_proofer_job_agent(config:, vendor:)
    allow(Figaro.env).to receive(config).and_return(vendor)

    agent = Idv::Agent.new({})
    allow(Idv::Agent).to receive(:new).and_return(agent)
  end

  context 'phone job' do
    describe '#perform' do
      let(:result_id) { SecureRandom.uuid }
      let(:applicant) { { first_name: 'Jean-Luc', last_name: 'Picard', phone: phone } }
      let(:applicant_json) { applicant.to_json }
      let(:phone) { '5555550000' }

      context 'when verification succeeds' do
        it 'should save a successful result' do
          Idv::ProoferJob.perform_now(
            result_id: result_id,
            applicant_json: applicant_json,
            stages: %i[phone]
          )
          result = VendorValidatorResultStorage.new.load(result_id)

          expect(result.success?).to eq(true)
          expect(result.timed_out?).to eq(false)
          expect(result.job_failed?).to eq(false)
          expect(result.reasons).to eq(['Good number'])
          expect(result.errors).to eq({})
        end
      end

      context 'when verification fails' do
        let(:phone) { '5555555555' }

        it 'should save an unsuccessful result' do
          Idv::ProoferJob.perform_now(
            result_id: result_id,
            applicant_json: applicant_json,
            stages: %i[phone]
          )
          result = VendorValidatorResultStorage.new.load(result_id)

          expect(result.success?).to eq(false)
          expect(result.timed_out?).to eq(false)
          expect(result.job_failed?).to eq(false)
          expect(result.reasons).to eq(['Bad number'])
          expect(result.errors).to eq(phone: 'The phone number could not be verified.')
        end
      end

      context 'when the idv agent raises' do
        before do
          agent = instance_double(Idv::Agent)
          allow(agent).to receive(:proof).and_raise(RuntimeError, '🔥🔥🔥')
          allow(Idv::Agent).to receive(:new).and_return(agent)
        end

        it 'should rescue from errors and save a failed job result' do
          expect do
            Idv::ProoferJob.perform_now(
              result_id: result_id,
              applicant_json: applicant_json,
              stages: %i[phone]
            )
          end.to raise_error(RuntimeError, '🔥🔥🔥')
          result = VendorValidatorResultStorage.new.load(result_id)

          expect(result.success?).to eq(false)
          expect(result.timed_out?).to eq(false)
          expect(result.job_failed?).to eq(true)
        end
      end

      it 'selects the proofer vendor based on the config' do
        mock_proofer_job_agent(config: :phone_proofing_vendor, vendor: 'fancy_vendor')

        Idv::ProoferJob.perform_now(
          result_id: result_id,
          applicant_json: applicant_json,
          stages: %i[phone]
        )
        result = VendorValidatorResultStorage.new.load(result_id)

        expect(Idv::Agent).to have_received(:new)
        expect(result).to be_a(Idv::VendorResult)
      end
    end
  end

  context 'profile job' do
    describe '#perform' do
      let(:result_id) { SecureRandom.uuid }
      let(:applicant) { {
        first_name: 'Jean-Luc',
        last_name: 'Picard',
        dob: '07/13/2035',
        state: 'VA',
        state_id_number: '123456789',
        state_id_type: 'drivers_license'
      } }

      let(:applicant_json) { applicant.to_json }

      it 'uses the state vendor params as the state id jurisdiction' do
        agent = Idv::Agent.new(applicant: {})
        allow(Idv::Agent).to receive(:new).and_return(agent).twice

        expect(agent).to receive(:proof).
          with(hash_including(state_id_jurisdiction: 'WA')).
          and_call_original

        Idv::ProoferJob.perform_now(
          result_id: result_id,
          applicant_json: applicant_json,
          stages: %i[profile state_id]
        )
        result = VendorValidatorResultStorage.new.load(result_id)

        expect(result).to be_a(Idv::VendorResult)
        expect(result.success?).to eq(true)
      end

      context 'when resolution and state id confirmation succeed' do
        it 'should save a successful result' do
          Idv::ProoferJob.perform_now(
            result_id: result_id,
            applicant_json: applicant_json,
            stages: %i[profile state_id]
          )
          result = VendorValidatorResultStorage.new.load(result_id)

          expect(result.success?).to eq(true)
          expect(result.timed_out?).to eq(false)
          expect(result.job_failed?).to eq(false)
          expect(result.normalized_applicant.first_name).to eq('JEAN-LUC')
          expect(result.normalized_applicant.last_name).to eq('PICARD')
          expect(result.reasons).to eq(['Everything looks good', 'valid state ID'])
          expect(result.errors).to eq({})
        end
      end

      context 'when resolution fails' do
        it 'should save an unsuccessful result and not call state id proofer' do
          applicant = { first_name: 'Bad' }
          agent = Idv::Agent.new(applicant: applicant)
          allow(agent).to receive(:proof).and_call_original
          allow(Idv::Agent).to receive(:new).and_return(agent)

          Idv::ProoferJob.perform_now(
            result_id: result_id,
            applicant_json: applicant_json,
            stages: %i[profile state_id]
          )
          result = VendorValidatorResultStorage.new.load(result_id)

          expect(result.success?).to eq(false)
          expect(result.timed_out?).to eq(false)
          expect(result.job_failed?).to eq(false)
          expect(result.reasons).to eq(['The name was suspicious'])
          expect(result.errors).to eq(first_name: 'Unverified first name.')
          expect(agent).to have_received(:start)
          expect(agent).to_not have_received(:submit_state_id)
        end
      end

      context 'when state id confirmation fails' do
        let(:applicant_json) { applicant.merge(state_id_number: '000000000').to_json }

        it 'saves an unsuccessful result' do
          Idv::ProoferJob.perform_now(
            result_id: result_id,
            applicant_json: applicant_json,
            stages: %i[profile state_id]
          )
          result = VendorValidatorResultStorage.new.load(result_id)

          expect(result.success?).to eq(false)
          expect(result.timed_out?).to eq(false)
          expect(result.job_failed?).to eq(false)
          expect(result.reasons).to eq(['Everything looks good', 'invalid state id number'])
          expect(result.errors).to eq(state_id_number: 'The state ID number could not be verified')
        end
      end

      context 'when the idv agent raises' do
        before do
          agent = instance_double(Idv::Agent)
          allow(agent).to receive(:proof).and_raise(RuntimeError, '🔥🔥🔥')
          allow(Idv::Agent).to receive(:new).and_return(agent)
        end

        it 'should rescue from errors and save a failed job result' do
          expect do
            Idv::ProoferJob.perform_now(
              result_id: result_id,
              applicant_json: applicant_json,
              stages: %i[profile state_id]
            )
          end.to raise_error(RuntimeError, '🔥🔥🔥')
          result = VendorValidatorResultStorage.new.load(result_id)

          expect(result.success?).to eq(false)
          expect(result.timed_out?).to eq(false)
          expect(result.job_failed?).to eq(true)
        end
      end

      it 'selects the vendors based on the config' do
        mock_proofer_job_agent(config: :profile_proofing_vendor, vendor: 'fancy_vendor')
        mock_proofer_job_agent(config: :state_id_proofing_vendor, vendor: 'fancier_vendor')

        Idv::ProoferJob.perform_now(
          result_id: result_id,
          applicant_json: applicant_json,
          stages: %i[profile state_id]
        )
        result = VendorValidatorResultStorage.new.load(result_id)

        expect(Idv::Agent).to have_received(:new)
        expect(result).to be_a(Idv::VendorResult)
      end
    end
  end
end
