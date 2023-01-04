require 'spec_helper'
require 'analytics_events_documenter'
require 'tempfile'

RSpec.describe AnalyticsEventsDocumenter do
  around do |ex|
    Dir.mktmpdir('.yardoc') do |database_dir|
      @database_dir = database_dir

      YARD::Registry.clear
      YARD::Tags::Library.define_tag(
        'Previous Event Name', AnalyticsEventsDocumenter::PREVIOUS_EVENT_NAME_TAG
      )
      YARD.parse_string(source_code)
      YARD::Registry.save(false, database_dir)

      ex.run
    end
  end

  let(:class_name) { 'AnalyticsEvents' }
  let(:require_extra_params) { true }

  subject(:documenter) do
    AnalyticsEventsDocumenter.new(
      database_path: @database_dir,
      class_name: class_name,
      require_extra_params: require_extra_params,
    )
  end

  describe '.run' do
    let(:source_code) { <<~RUBY }
      class AnalyticsEvents
        # @param [Boolean] success
        def some_event(success:, **extra)
          track_event('Some Event')
        end
      end
    RUBY

    subject(:run) { AnalyticsEventsDocumenter.run(args) }

    context 'with --help' do
      let(:args) { ['--help'] }

      it 'prints help' do
        output, status = run

        expect(output).to include('Usage')
        expect(status).to eq(0)
      end
    end

    context 'with --check' do
      let(:args) { ['--check', @database_dir] }

      it 'prints a rocket when there are no errors' do
        output, status = run

        expect(output).to include('🚀')
        expect(status).to eq(0)
      end
    end

    context 'with --json' do
      let(:args) { ['--json', @database_dir] }

      it 'prints json output' do
        output, status = run

        expect(JSON.parse(output, symbolize_names: true)).to have_key(:events)
        expect(status).to eq(0)
      end
    end
  end

  describe '#missing_documentation' do
    context 'when all methods have all documentation' do
      let(:source_code) { <<~RUBY }
        class AnalyticsEvents
          # @param [Boolean] success
          def some_event(success:, **extra)
            track_event('Some Event')
          end
        end
      RUBY

      it 'is empty' do
        expect(documenter.missing_documentation).to be_empty
      end
    end

    context 'when a method is missing an event name' do
      let(:source_code) { <<~RUBY }
        class AnalyticsEvents
          def some_event; end
        end
      RUBY

      it 'reports the missing tag' do
        expect(documenter.missing_documentation.first).
          to include('some_event event name not detected')
      end
    end

    context 'when a method is missing documentation for a param' do
      let(:source_code) { <<~RUBY }
        class AnalyticsEvents
          def some_event(success:)
            track_event('Some Event')
          end
        end
      RUBY

      it 'reports the missing tag' do
        expect(documenter.missing_documentation.first).
          to include('some_event success (undocumented)')
      end
    end

    context 'when a method includes a positional param' do
      let(:source_code) { <<~RUBY }
        class AnalyticsEvents
          def some_event(success)
            track_event('Some Event')
          end
        end
      RUBY

      it 'reports the invalid param' do
        expect(documenter.missing_documentation.first).
          to include('some_event unexpected positional parameters ["success"]')
      end
    end

    context 'when a method skips documenting an param, such as pii_like_keypaths' do
      let(:source_code) { <<~RUBY }
        class AnalyticsEvents
          def some_event(pii_like_keypaths:, **extra)
            track_event('Some Event')
          end
        end
      RUBY

      it 'allows documentation to be missing' do
        expect(documenter.missing_documentation).to be_empty
      end
    end

    context 'when a method documents a param but leaves out types' do
      let(:source_code) { <<~RUBY }
        class AnalyticsEvents
          # @param success
          def some_event(success:, **extra)
            track_event('Some Event')
          end
        end
      RUBY

      it 'has an error documentation to be missing' do
        expect(documenter.missing_documentation.first).
          to include('some_event success missing types')
      end
    end

    context 'when a method does not have a **extra param' do
      let(:require_extra_params) { true }

      let(:source_code) { <<~RUBY }
        class AnalyticsEvents
          # @param [Boolean] success
          def some_event(success:)
            track_event('Some Event')
          end
        end
      RUBY

      it 'requires **extra param' do
        expect(documenter.missing_documentation.first).to include('some_event missing **extra')
      end

      context 'when require_extra_params is false' do
        let(:require_extra_params) { false }

        it 'allows **extra to be missing' do
          expect(documenter.missing_documentation).to be_empty
        end
      end
    end

    context 'when a method has * as its only arg' do
      let(:source_code) { <<~RUBY }
        class AnalyticsEvents
          def some_event(*)
            track_event('Some Event')
          end
        end
      RUBY

      it 'errors' do
        expect(documenter.missing_documentation.first).to include("don't use * as an argument")
      end
    end
  end

  describe '#as_json' do
    let(:source_code) { <<~RUBY }
      class AnalyticsEvents
        # @param [Boolean] success
        # @param [Integer] count number of attempts
        # The event that does something with stuff
        def some_event(success:, count:)
          track_event('Some Event')
        end

        # @identity.idp.previous_event_name The Old Other Event
        # @identity.idp.previous_event_name Even Older Other Event
        def other_event
          track_event('Other Event')
        end
      end
    RUBY

    it 'is a JSON representation of params for each event' do
      expect(documenter.as_json[:events]).to match_array(
        [
          {
            event_name: 'Some Event',
            previous_event_names: [],
            description: 'The event that does something with stuff',
            attributes: [
              { name: 'success', types: ['Boolean'], description: nil },
              { name: 'count', types: ['Integer'], description: 'number of attempts' },
            ],
            method_name: :some_event,
            source_file: '(stdin)',
            source_line: 5,
            source_sha: kind_of(String),
          },
          {
            event_name: 'Other Event',
            previous_event_names: [
              'The Old Other Event',
              'Even Older Other Event',
            ],
            description: nil,
            attributes: [],
            method_name: :other_event,
            source_file: '(stdin)',
            source_line: 11,
            source_sha: kind_of(String),
          },
        ],
      )
    end

    context 'with a namespaced class name, with symbol event names' do
      let(:class_name) { 'Foobar::CustomEvents' }

      let(:source_code) { <<~RUBY }
        module Foobar
          class CustomEvents
            # @param [Boolean] success
            def some_event(success:, **extra)
              track_event(:some_event)
            end
          end
        end
      RUBY

      it 'still finds events' do
        expect(documenter.as_json[:events]).to match_array(
          [
            {
              event_name: 'some_event',
              previous_event_names: [],
              description: '',
              attributes: [
                { name: 'success', types: ['Boolean'], description: nil },
              ],
              method_name: :some_event,
              source_file: '(stdin)',
              source_line: 4,
              source_sha: kind_of(String),
            },
          ],
        )
      end
    end
  end
end
