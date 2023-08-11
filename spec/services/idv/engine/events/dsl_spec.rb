require 'rails_helper'

RSpec.describe 'Events DSL' do
  EventsModule = Module.new do
    include Idv::Engine::Events::Dsl

    event :idv_started do
      description 'The user started IdV.'
    end

    event :idv_gpo_started do
      description 'The user has started GPO'
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

    instance.idv_started
  end

  
  xit 'has static methods for wiring up event handlers' do
    ConsumerClassWithHandlers = Class.new do
      include EventsModule

      attr_reader :idv_started_calls

      on :idv_started do
        @idv_started_calls ||= 0
        @idv_started_calls += 1
      end
    end

    instance = ConsumerClassWithHandlers.new
    expect { instance.idv.started }.to change { instance.idv_started_calls }
  end
end
