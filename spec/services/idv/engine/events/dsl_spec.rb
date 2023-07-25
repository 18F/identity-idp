require 'rails_helper'

RSpec.describe 'Events DSL' do
  EventsModule = Module.new do
    include Idv::Engine::Events::Dsl

    namespace :idv do
      description 'Events related to identity verification (IdV).'

      event :started do
        description 'The user started IdV.'
      end

      namespace :gpo do
        event :started do
          description 'The user has started GPO'
        end
      end
    end
  end

  ConsumerClass = Class.new do
    include EventsModule

    private

    def handle_event(event, payload = nil)
    end
  end

  it 'has callable instance methods for events' do
    instance = ConsumerClass.new
    expect(instance).to receive(:handle_event)

    instance.idv.started
  end

  it 'has callable methods for  nested namespaces' do
    instance = ConsumerClass.new
    expect { instance.idv.gpo.started }.not_to raise_error
  end

  it 'has static methods for wiring up event handlers' do
    ConsumerClassWithHandlers = Class.new do
      include EventsModule

      attr_reader :idv_started_calls

      on :idv, :started do
        @idv_started_calls ||= 0
        @idv_started_calls += 1
      end
    end

    instance = ConsumerClassWithHandlers.new
    expect { instance.idv.started }.to change { instance.idv_started_calls }
  end
end
