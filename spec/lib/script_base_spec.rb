require 'spec_helper'
require 'script_base'

RSpec.describe ScriptBase do
  let(:subtask_class) do
    Class.new do
      def run(args:, config:) # rubocop:disable Lint/UnusedMethodArgument
        ScriptBase::Result.new(
          table: [
            %w[header1 header2],
            %w[value1 value2],
          ],
          subtask: 'example-subtask',
          uuids: %w[a b c],
        )
      end
    end
  end

  let(:stdout) { StringIO.new }
  let(:stderr) { StringIO.new }

  describe '#run' do
    let(:argv) { [] }
    let(:env) { 'production' }

    subject(:base) do
      ScriptBase.new(
        argv:,
        stdout:,
        stderr:,
        subtask_class:,
        banner: '',
        reason_arg: false,
        rails_env: ActiveSupport::EnvironmentInquirer.new(env),
      )
    end

    context 'running in production vs locally' do
      subject(:run) { base.run }

      context 'in production' do
        let(:env) { 'production' }

        it 'does not warn' do
          run

          expect(stderr.string).to_not include('WARNING')
        end
      end

      context 'in development' do
        let(:env) { 'development' }

        it 'warns that it is in development' do
          run

          expect(stderr.string).to include('WARNING: returning local data')
        end
      end
    end

    context 'with --deflate' do
      let(:argv) { %w[--deflate] }

      it 'applies DEFLATE compression to the output' do
        base.run

        table = subtask_class.new.run(args: nil, config: nil).table

        expect(JSON.parse(Zlib::Inflate.inflate(Base64.decode64(stdout.string)))).to eq(table)
      end
    end

    context 'throwing an error inside the task' do
      let(:subtask_class) do
        Class.new do
          def run(args:, config:) # rubocop:disable Lint/UnusedMethodArgument
            raise 'some dangerous error'
          end
        end
      end

      before do
        base.config.format = :csv
      end

      it 'logs the error message in the output but not the backtrace' do
        expect { base.run }.to_not raise_error

        expect(CSV.parse(stdout.string)).to eq(
          [
            %w[Error Message],
            ['RuntimeError', 'some dangerous error'],
          ],
        )
      end
    end
  end
end
