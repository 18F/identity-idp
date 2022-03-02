require 'spec_helper'
require 'analytics_events_documenter'
require 'tempfile'

RSpec.describe AnalyticsEventsDocumenter do
  around do |ex|
    Dir.mktmpdir('.yardoc') do |database_dir|
      @database_dir = database_dir

      YARD::Registry.clear
      YARD::Tags::Library.define_tag("Event Name", :'identity.idp.event_name')
      YARD.parse_string(source_code)
      YARD::Registry.save(false, database_dir)

      ex.run
    end
  end

  subject(:documenter) { AnalyticsEventsDocumenter.new(@database_dir) }

  describe '#missing_documentation' do
    context 'when all methods have all documentation' do
      let(:source_code) { <<~RUBY }
        class AnalyticsEvents
          # @identity.idp.event_name Some Event
          # @param [Boolean] success
          def some_event(success:)
          end
        end
      RUBY

      it 'is empty' do
        expect(documenter.missing_documentation).to be_empty
      end
    end

    context 'when a method is missing the event_name tag' do
      let(:source_code) { <<~RUBY }
        class AnalyticsEvents
          def some_event; end
        end
      RUBY

      it 'reports the missing tag' do
        expect(documenter.missing_documentation.first).
          to include('some_event missing @identity.idp.event_name')
      end
    end

    context 'when a method is missing documentation for a param' do
      let(:source_code) { <<~RUBY }
        class AnalyticsEvents
          # @identity.idp.event_name Some Event
          def some_event(success:); end
        end
      RUBY

      it 'reports the missing tag' do
        expect(documenter.missing_documentation.first).
          to include('some_event success (undocumented)')
      end
    end

    context 'when a method is skips documenting an param, such as pii_like_keypaths' do
      let(:source_code) { <<~RUBY }
        class AnalyticsEvents
          # @identity.idp.event_name Some Event
          def some_event(pii_like_keypaths:); end
        end
      RUBY

      it 'allow documentation to be missing' do
        expect(documenter.missing_documentation).to be_empty
      end
    end
  end

  describe '#as_json' do
    let(:source_code) { <<~RUBY }
      class AnalyticsEvents
        # @identity.idp.event_name Some Event
        # @param [Boolean] success
        # @param [Integer] count number of attempts
        # The event that does something with stuff
        def some_event(success:, count:); end

        # @identity.idp.event_name Other Event
        def other_event; end
      end
    RUBY

    it 'is a JSON representation of params for each event' do
      expect(documenter.as_json[:events]).to match_array(
        [
          {
            event_name: 'Some Event',
            description: 'The event that does something with stuff',
            attributes: [
              { name: 'success', types: ['Boolean'], description: nil },
              { name: 'count', types: ['Integer'], description: 'number of attempts' },
            ],
          },
          {
            event_name: 'Other Event',
            description: nil,
            attributes: [],
          },
        ],
      )
    end
  end
end
