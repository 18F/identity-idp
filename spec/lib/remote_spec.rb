require 'spec_helper'

require 'remote'

RSpec.describe Remote do
  subject(:remote) { Remote.new }

  describe '#parse' do
    subject(:parse) { remote.parse(argv) }

    context 'without any args' do
      let(:argv) { [] }

      it 'prints help and exits' do
        expect(Kernel).to receive(:puts)
        expect(Kernel).to receive(:exit).with(0)

        parse
      end
    end

    context 'with just a stage' do
      let(:argv) { ['qa'] }

      it 'sets the stage' do
        expect(parse.stage).to eq('qa')
      end

      it 'defaults to the console command' do
        expect(parse.command).to eq('console')
      end
    end

    context 'with a stage and a command' do
      let(:argv) { %w(demo shell) }

      it 'sets the stage' do
        expect(parse.stage).to eq('demo')
      end

      it 'sets the command' do
        expect(parse.command).to eq('shell')
      end
    end

    context 'with the --worker flag' do
      let(:argv) { ['--worker', 'qa'] }

      it 'sets the subhost to worker' do
        expect(parse.subhost).to eq('worker')
      end
    end

    context 'specifying stage and command as flags' do
      let(:argv) { ['--stage', 'demo', '--command', 'echo hi'] }

      it 'sets the stage and command' do
        expect(parse.stage).to eq('demo')
        expect(parse.command).to eq('echo hi')
      end
    end

    context 'with a command after a --' do
      let(:argv) { ['qa', '--', 'echo', 'hi'] }

      it 'extracts the command' do
        expect(parse.command).to eq(%w(echo hi))
      end
    end
  end

  describe '#command' do
    let(:config) { OpenStruct.new(command: command) }

    context 'with console' do
      let(:command) { 'console' }

      it 'opens a rails console' do
        expect(remote.command(config)).
          to eq('RAILS_ENV=production bundle exec rails console')
      end
    end

    context 'with shell' do
      let(:command) { 'shell' }

      it 'opens a bash shell' do
        expect(remote.command(config)).to eq('bash --login')
      end
    end

    context 'with a custom command' do
      let(:command) { 'echo hi' }

      it 'is that custom command' do
        expect(remote.command(config)).to eq('echo hi')
      end
    end
  end

  describe '#execute' do
    let(:config) do
      OpenStruct.new(
        host: 'demo',
        command: 'echo hi'
      )
    end

    before { expect(Kernel).to receive(:puts) }

    subject(:exec_args) do
      exec_args = nil
      expect(remote).to receive(:exec) do |*args|
        exec_args = args
      end

      remote.execute(config)

      exec_args
    end

    it 'runs ssh -t' do
      expect(exec_args.first(2)).to eq(['ssh', '-t'])
    end

    it 'logs in as the ubuntu user' do
      expect(exec_args[2]).to start_with('ubuntu@')
    end

    it 'runs from the current directory' do
      expect(exec_args[3]).to eq('cd /srv/idp/current; ')
    end
  end
end
