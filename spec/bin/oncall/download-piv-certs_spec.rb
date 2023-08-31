require 'rails_helper'
load Rails.root.join('bin/oncall/download-piv-certs')

RSpec.describe DownloadPivCerts do
  describe '.parse!' do
    let(:out) { StringIO.new }
    subject(:parse!) { DownloadPivCerts.parse!(argv: argv, stdout: out) }

    context 'with --help' do
      let(:argv) { %w[--help] }

      it 'prints help and exits uncleanly' do
        expect(DownloadPivCerts).to receive(:exit).with(1)

        parse!

        expect(out.string).to include('Usage:')
      end
    end

    context 'with no arguments' do
      let(:argv) { [] }

      it 'prints help and exits uncleanly' do
        expect(DownloadPivCerts).to receive(:exit).with(1)

        parse!

        expect(out.string).to include('Usage:')
      end
    end

    context 'with arguments' do
      let(:argv) { %w[abc def] }

      it 'returns an instance populated with UUIDs' do
        expect(parse!.uuids).to eq(%w[abc def])
      end

      context 'with --out' do
        let(:argv) { [*super(), '--out', '/tmp/my-dir'] }

        it 'sets the output directory' do
          expect(parse!.out_dir).to eq('/tmp/my-dir')
        end
      end
    end
  end

  describe '#run' do
    let(:instance) do
      DownloadPivCerts.new(
        uuids: %w[abc123],
        out_dir: @out_dir,
        progress_bar: false,
        stdout: stdout,
      )
    end
    let(:stdout) { StringIO.new }

    subject(:run) { instance.run }

    around do |ex|
      Dir.mktmpdir('/certs') do |out_dir|
        @out_dir = out_dir

        ex.run
      end
    end

    let(:cloudwatch_client) do
      instance_double(
        'Reporting::CloudwatchClient',
        fetch: [
          { 'user_id' => 'abc123', 'key_id' => 'key123' },
        ],
      )
    end

    before do
      Aws.config[:sts] = {
        stub_responses: {
          get_caller_identity: {
            account: 'account123',
          },
        },
      }

      Aws.config[:s3] = {
        stub_responses: {
          list_objects_v2: {
            contents: [
              key: 'full-key-123',
            ],
          },
          get_object: {
            body: 'pem-123',
          },
        },
      }

      allow(instance).to receive(:cloudwatch_client).and_return(cloudwatch_client)
    end

    it 'writes certs to the tmpdir' do
      run

      path = File.join(@out_dir, 'abc123', 'key123.pem')
      expect(File.read(path)).to eq('pem-123')

      expect(stdout.string).to include(path)
    end
  end
end
