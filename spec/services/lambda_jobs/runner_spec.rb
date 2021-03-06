require 'rails_helper'

RSpec.describe LambdaJobs::Runner do
  subject(:runner) do
    LambdaJobs::Runner.new(args: args, job_class: job_class, in_process_config: in_process_config)
  end

  let(:args) { { foo: 'bar' } }
  let(:job_class) { double('JobClass', name: 'SomeModule::OtherModule::JobClass') }
  let(:in_process_config) { { key: 'secret' } }
  let(:aws_lambda_proofing_enabled) { 'true' }

  let(:env) { 'dev' }
  let(:git_ref) { '1234567890abcdefghijklmnop' }
  before do
    stub_const('LambdaJobs::GIT_REF', git_ref)
    allow(Identity::Hostdata).to receive(:env).and_return(env)
  end

  describe '#function_name' do
    it 'has the env, job class and first 10 characters of the GIT_REF' do
      expect(runner.function_name).to eq('dev-idp-functions-JobClassFunction:1234567890')
    end
  end

  describe '#run' do
    before do
      allow(Identity::Hostdata).to receive(:in_datacenter?).and_return(in_datacenter)
      allow(AppConfig.env).to receive(:aws_lambda_proofing_enabled).
        and_return(aws_lambda_proofing_enabled)
    end

    context 'when run in a deployed environment' do
      let(:in_datacenter) { true }

      context 'when aws_lambda_proofing_enabled is true' do
        let(:aws_lambda_proofing_enabled) { 'true' }

        let(:aws_lambda_client) { instance_double(Aws::Lambda::Client) }
        before do
          expect(runner).to receive(:aws_lambda_client).and_return(aws_lambda_client)
        end

        it 'involves a lambda in AWS, without sending in_process_config' do
          expect(aws_lambda_client).to receive(:invoke).with(
            function_name: 'dev-idp-functions-JobClassFunction:1234567890',
            invocation_type: 'Event',
            log_type: 'None',
            payload: args.to_json,
          )

          runner.run
        end
      end

      context 'when aws_lambda_proofing_enabled is false' do
        let(:aws_lambda_proofing_enabled) { 'false' }

        it 'calls JobClass.handle' do
          expect(job_class).to receive(:handle).with(
            event: args.merge(in_process_config),
            context: nil,
          )

          runner.run
        end
      end
    end

    context 'when run locally' do
      let(:in_datacenter) { false }

      it 'calls JobClass.handle, merging in including in_process_config' do
        expect(job_class).to receive(:handle).with(
          event: args.merge(in_process_config),
          context: nil,
        )

        runner.run
      end

      context 'when run locally with a block' do
        it 'passes the block to the handler' do
          result = Object.new

          expect(job_class).to receive(:handle).with(
            event: args.merge(in_process_config),
            context: nil,
          ).and_yield(result)

          yielded_result = nil
          runner.run do |callback_result|
            yielded_result = callback_result
          end

          expect(yielded_result).to eq(result)
        end
      end
    end
  end
end
