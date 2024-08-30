require 'spec_helper'
require 'rack/utils'
load File.expand_path('../../scripts/notify-slack', __dir__)

RSpec.describe NotifySlack do
  subject(:notifier) { described_class.new }

  let(:webhook) { 'https://slack.example.com/abcdef/ghijkl' }
  let(:channel) { '#fun-channel' }
  let(:username) { 'notifier-bot' }
  let(:text) { 'my message' }
  let(:icon) { ':red_circle:' }

  describe '#run' do
    let(:argv) do
      [
        '--webhook',
        webhook,
        '--channel',
        channel,
        '--username',
        username,
        '--text',
        text,
        '--icon', icon
      ]
    end
    let(:stdin) { StringIO.new }
    let(:stdout) { StringIO.new }

    subject(:run) do
      notifier.run(argv:, stdin:, stdout:)
    end

    before do
      allow(notifier).to receive(:exit)
    end

    context 'missing required argument' do
      before do
        argv.delete('--webhook')
        argv.delete(webhook)
      end

      it 'prints help and exits uncleanly' do
        expect(notifier).to receive(:exit).with(1)

        run

        expect(stdout.string).to include('Usage')
      end
    end

    it 'notifies' do
      post_request = stub_request(:post, webhook)

      run

      expect(post_request).to have_been_made
    end

    context 'network error' do
      before do
        stub_request(:post, webhook).to_return(status: 500)
      end

      it 'prints an error and exits cleanly' do
        expect(notifier).to_not receive(:exit)

        run

        expect(stdout.string).to include('ERROR: 500')
      end

      context 'with --raise' do
        before { argv << '--raise' }

        it 'raises an error' do
          expect { run }.to raise_error(Net::HTTPExceptions)
        end
      end
    end
  end

  describe '#notify' do
    subject(:notify) do
      notifier.notify(webhook:, channel:, username:, text:, icon:)
    end

    it 'POSTs JSON inside of form encoding to the webhook' do
      post_request = stub_request(:post, webhook).with(
        headers: {
          content_type: 'application/x-www-form-urlencoded',
        },
      ) do |req|
        form = Rack::Utils.parse_query(req.body)
        expect(JSON.parse(form['payload'], symbolize_names: true)).to eq(
          channel:,
          username:,
          text:,
          icon_emoji: icon,
        )
      end

      notify

      expect(post_request).to have_been_made
    end
  end

  describe '#format_icon' do
    it 'adds colons around icon names if missing' do
      expect(notifier.format_icon('joy')).to eq(':joy:')
    end

    it 'leaves colons around icon names if present' do
      expect(notifier.format_icon(':sob:')).to eq(':sob:')
    end
  end
end
