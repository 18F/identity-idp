require 'rails_helper'

RSpec.describe 'Events DSL' do
  EventsModule = Module.new do
    include Idv::Engine::Events::Dsl

    namespace :idv do
      event :started do
        description 'The user starts IdV'
      end

      namespace :gpo do
      end
    end
  end

  ConsumerClass = Class.new do
    include EventsModule
  end

  it 'has the right root namespaces' do
    expect(ConsumerClass.event_namespaces).to eql(
      [
        :idv,
      ],
    )
  end

  it 'has callable instance methods for events' do
    instance = ConsumerClass.new
    expect { instance.idv.started }.not_to raise_error
  end

  it 'has callable methods for in nested namespaces' do
    instance = ConsumerClass.new
    expect { instance.idv.gpo.started }.not_to raise_error
  end

  it 'has static methods for wiring up event handlers' do
  end
end
