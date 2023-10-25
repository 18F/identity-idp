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

    subject(:base) do
      ScriptBase.new(
        argv:,
        stdout:,
        stderr:,
        subtask_class:,
        banner: '',
      )
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

      it 'logs the error message to stderr but not the backtrace' do
        expect(base).to receive(:exit).with(1)

        expect { base.run }.to_not raise_error

        expect(stderr.string.chomp).to eq('RuntimeError: some dangerous error')
        expect(JSON.parse(stdout.string)).to eq(
          [
            %w[Error Message],
            ['RuntimeError', 'some dangerous error'],
          ],
        )
      end
    end
  end
end
