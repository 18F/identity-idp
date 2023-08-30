require 'rails_helper'

RSpec.describe FrontendLogger do
  module ExampleAnalyticsEvents
    def example_method_handler(ok:, **rest)
      track_event('example', ok: ok, rest: rest)
    end
  end

  let(:analytics_class) do
    Class.new(FakeAnalytics) do
      include ExampleAnalyticsEvents
    end
  end
  let(:analytics) { analytics_class.new }

  let(:event_map) do
    {
      'method' => ExampleAnalyticsEvents.instance_method(:example_method_handler),
      'proc' => proc do |analytics, payload|
        analytics.track_event('some customized event', payload.merge('custom' => true))
      end,
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

    context 'with method handler' do
      let(:name) { 'method' }

      it 'calls method with attributes based on signature' do
        call

        expect(analytics).to have_logged_event('example', ok: true, rest: {})
      end
    end

    context 'with proc handler' do
      let(:name) { 'proc' }

      it 'calls the method and passes analytics and attributes' do
        call

        expect(analytics).to have_logged_event(
          'some customized event', 'ok' => true, 'other' => true, 'custom' => true
        )
      end
    end
  end
end
