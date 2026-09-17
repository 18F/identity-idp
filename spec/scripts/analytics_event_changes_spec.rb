require 'spec_helper'
require_relative '../../scripts/analytics_event_changes'

RSpec.describe AnalyticsEventChanges do
  describe '.detect' do
    let(:base_analytics_events) do
      <<~RUBY
        module AnalyticsEvents
          # Existing event
          def existing_event(foo:, **extra)
            track_event('Existing Event', foo: foo, **extra)
          end
        end
      RUBY
    end
    let(:base_controller) do
      <<~RUBY
        class ExampleController
          def show
            analytics.existing_event(foo: 'old')
          end
        end
      RUBY
    end

    def detect_changes(
      changed_files:,
      source_analytics_events:,
      source_controller:,
      base_controller: self.base_controller
    )
      described_class.detect(
        changed_files: changed_files,
        base_files: {
          described_class::ANALYTICS_EVENTS_FILE => base_analytics_events,
          'app/controllers/example_controller.rb' => base_controller,
        },
        source_files: {
          described_class::ANALYTICS_EVENTS_FILE => source_analytics_events,
          'app/controllers/example_controller.rb' => source_controller,
        },
      )
    end

    it 'detects new events' do
      source_analytics_events =
        <<~RUBY
          module AnalyticsEvents
            # Existing event
            def existing_event(foo:, **extra)
              track_event('Existing Event', foo: foo, **extra)
            end

            # New event
            def new_event(**extra)
              track_event('New Event', **extra)
            end
          end
        RUBY

      changes = detect_changes(
        changed_files: [described_class::ANALYTICS_EVENTS_FILE],
        source_analytics_events: source_analytics_events,
        source_controller: base_controller,
      )

      expect(changes.map(&:type)).to contain_exactly(:new_event)
      expect(changes.first.method_name).to eq('new_event')
    end

    it 'detects new instances of existing events' do
      source_controller =
        <<~RUBY
          class ExampleController
            def show
              analytics.existing_event(foo: 'old')
              analytics.track_event(:existing_event, foo: 'new')
            end
          end
        RUBY

      changes = detect_changes(
        changed_files: ['app/controllers/example_controller.rb'],
        source_analytics_events: base_analytics_events,
        source_controller: source_controller,
      )

      expect(changes.map(&:type)).to contain_exactly(:new_or_changed_invocation)
      expect(changes.first.method_name).to eq('existing_event')
      expect(changes.first.source).to eq("analytics.track_event(:existing_event, foo: 'new')")
    end

    it 'detects changes to existing events definition' do
      source_analytics_events =
        <<~RUBY
          module AnalyticsEvents
            # Existing event with a new payload attribute
            def existing_event(foo:, bar: nil, **extra)
              track_event('Existing Event', foo: foo, bar: bar, **extra)
            end
          end
        RUBY

      changes = detect_changes(
        changed_files: [described_class::ANALYTICS_EVENTS_FILE],
        source_analytics_events: source_analytics_events,
        source_controller: base_controller,
      )

      expect(changes.map(&:type)).to contain_exactly(:changed_event_definition)
      expect(changes.first.method_name).to eq('existing_event')
    end

    it 'detects changes to the payload of existing event invocations' do
      source_controller =
        <<~RUBY
          class ExampleController
            def show
              analytics.existing_event(
                foo: 'new',
              )
            end
          end
        RUBY

      changes = detect_changes(
        changed_files: ['app/controllers/example_controller.rb'],
        source_analytics_events: base_analytics_events,
        source_controller: source_controller,
      )

      expect(changes.map(&:type)).to contain_exactly(:new_or_changed_invocation)
      expect(changes.first.method_name).to eq('existing_event')
      expect(changes.first.source).to eq('analytics.existing_event(')
    end

    it 'detects changes to the content of splatted keyword payloads' do
      base_controller =
        <<~RUBY
          class ExampleController
            def show
              analytics.existing_event(**analytics_params)
            end

            def analytics_params
              { foo: 'old' }
            end
          end
        RUBY
      source_controller =
        <<~RUBY
          class ExampleController
            def show
              analytics.existing_event(**analytics_params)
            end

            def analytics_params
              { foo: 'new' }
            end
          end
        RUBY

      changes = detect_changes(
        changed_files: ['app/controllers/example_controller.rb'],
        source_analytics_events: base_analytics_events,
        source_controller: source_controller,
        base_controller: base_controller,
      )

      expect(changes.map(&:type)).to contain_exactly(:new_or_changed_invocation)
      expect(changes.first.method_name).to eq('existing_event')
      expect(changes.first.source).to eq('analytics.existing_event(**analytics_params)')
    end

    it 'does not report changes when analytics events are unchanged' do
      changes = detect_changes(
        changed_files: ['app/controllers/example_controller.rb'],
        source_analytics_events: base_analytics_events,
        source_controller: base_controller,
      )

      expect(changes).to be_empty
    end
  end

  describe '.format_changes' do
    it 'formats an empty result' do
      expect(described_class.format_changes([])).to eq("No analytics event changes detected.\n")
    end
  end
end
