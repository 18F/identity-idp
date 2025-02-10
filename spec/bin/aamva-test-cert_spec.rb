require 'rails_helper'
load Rails.root.join('bin/aamva-test-cert')

RSpec.describe AamvaTestCert do
  let(:fake_aamva_test) do
    Class.new do
      def test_cert(auth_url:, verification_url:)
        [auth_url, verification_url]
      end
    end
  end

  before { stub_const('AamvaTest', fake_aamva_test) }

  subject(:instance) { AamvaTestCert.new }

  describe '#run' do
    subject(:run) { instance.run(out: out, argv: argv) }
    let(:out) { StringIO.new('') }
    let(:argv) { [] }

    context 'missing arguments' do
      let(:argv) { [] }

      it 'exits uncleanly' do
        expect(instance).to receive(:exit).with(1)

        run
      end
    end

    context '--help' do
      let(:argv) { %w[--help] }

      it 'exits cleanly and prints help' do
        expect(instance).to receive(:exit).with(0)

        run

        expect(out.string).to include('Usage:')
      end
    end

    context 'required arguments' do
      let(:argv) { %w[--auth-url a --verification-url b] }

      it 'pretty-prints the result' do
        run

        expect(JSON.parse(out.string)).to eq(%w[a b])
      end
    end
  end
end
