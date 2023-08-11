# This file defines a domain-specific language (DSL) for configuring events inside an IdvEngine.

module Idv::Engine::Events::Dsl
  class Event
    attr_reader :name

    def initialize(name, &block)
      @name = name
      instance_eval(&block)
    end

    def description(value = nil)
      @description = value unless value.nil?
      @description
    end
  end

  def self.included(base)
    puts '--------------------'
    puts base.inspect
    puts '--------------------'
    base.class_eval do
      # Make an `event` method available for defining root namespaces.
      def self.event(name, &block)
        @events ||= []
        @events << Event.new(name, &block)
      end

      # When our module is itself included, add helper methods for all events
      def self.included(base)
        @events.each do |event|
          base.define_method(event.name) { event }
        end

        # base.extend(HelperMethods)
      end
    end
  end
end
