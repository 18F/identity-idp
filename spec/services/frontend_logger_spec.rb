require 'rails_helper'

describe FrontendLogger do
  module ExampleAnalyticsEvents
    def example_method_handler(ok:, **rest)
      track_event('example', ok: ok, rest: rest)
    end
  end

  class ExampleAnalytics < FakeAnalytics
    include ExampleAnalyticsEvents
  end

  let(:analytics) { ExampleAnalytics.new }
  let(:proc_handler) { proc {} }
  let(:event_map) do
    {
      'proc' => proc_handler,
      'method' => ExampleAnalyticsEvents.instance_method(:example_method_handler),
    }
  end
  let(:logger) { described_class.new(analytics: analytics, event_map: event_map) }

  describe '#track_event' do
    let(:name) { nil }
    let(:attributes) { { 'ok' => true, 'other' => true } }

    subject(:call) { logger.track_event(name, attributes) }

    context 'with unknown event' do
      let(:name) { 'unknown' }

      it 'logs with prefix for unknown event' do
        call

        expect(analytics).to have_logged_event('Frontend: unknown', attributes)
      end
    end

    context 'with proc event handler' do
      let(:name) { 'proc' }

      it 'calls proc with analytics instance' do
        expect(proc_handler).to receive(:call).with(analytics, attributes)

        call
      end
    end

    context 'with method handler' do
      let(:name) { 'method' }

      it 'calls method with attributes based on signature' do
        call

        expect(analytics).to have_logged_event('example', ok: true, rest: {})
      end
    end
  end
end
