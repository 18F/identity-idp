require 'rails_helper'

RSpec.describe FrontendLogger do
  let(:example_analytics_mixin) do
    Module.new do
      def example_method_handler(ok:, **rest)
        track_event('example', ok: ok, rest: rest)
      end
    end
  end

  let(:analytics_class) do
    mixin = example_analytics_mixin

    Class.new(FakeAnalytics) do
      include mixin
    end
  end
  let(:analytics) { analytics_class.new }

  let(:event_map) do
    {
      'method' => analytics.method(:example_method_handler),
      'proc' => lambda do |ok:, other:|
        analytics.track_event('some customized event', 'ok' => ok, 'other' => other, 'custom' => 1)
      end,
    }
  end
  let(:logger) { described_class.new(analytics: analytics, event_map: event_map) }

  describe '#track_event' do
    let(:name) { nil }
    let(:attributes) { { 'ok' => true, 'other' => true } }

    subject(:call) { logger.track_event(name, attributes) }

    context 'with unknown event' do
      let(:name) { :test_event }

      it { expect(call).to eq(false) }
    end

    context 'with method handler' do
      let(:name) { 'method' }

      it { expect(call).to eq(true) }

      it 'calls method with attributes based on signature' do
        call

        expect(analytics).to have_logged_event('example', ok: true, rest: {})
      end
    end

    context 'with proc handler' do
      let(:name) { 'proc' }

      it { expect(call).to eq(true) }

      it 'calls the method and passes analytics and attributes' do
        call

        expect(analytics).to have_logged_event(
          'some customized event', 'ok' => true, 'other' => true, 'custom' => 1
        )
      end
    end
  end
end
