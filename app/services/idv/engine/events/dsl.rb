module Idv::Engine::Events::Dsl
  def self.included(base)
    # The module Dsl is included in will be used to define a set of available events
    base.extend(DslMethods)

    # When _that_ module is then included somewhere else, it will make several helper
    # methods available for interacting with the events defined.
    base.class_eval do
      def self.included(base)
        base.class_variable_set(:@@root_namespaces, @root_namespaces.dup.freeze)
        base.extend(HelperMethods)
      end
    end
  end

  module DslMethods
    def namespace(name, &block)
      @root_namespaces ||= []
      @root_namespaces << Objects::Namespace.new(name, &block)
    end
  end

  module Objects
    class Namespace
      attr_reader :name, :events
      def initialize(name, &block)
        @name = name
        @namespaces = []
        @events = []

        instance_eval(&block)
      end

      def event(name, &block)
        puts "event #{name}"
        @events << Event.new(name, &block)
      end

      def namespace(name, &block)
        puts "namespace #{name}"
        @namespaces << Namespace.new(name, &block)
      end
    end

    class Event
      attr_reader :name
      def initialize(name)
        @name = name
      end
    end
  end

  module HelperMethods
    def event_namespaces
      (self.class_variable_get(:@@root_namespaces) || []).
        pluck(:name)
    end

    # Takes an aribitrary event name and splits it out into [namespace, event_name]
    # where namespaces is an array.
    def parse_event_name(event_name)
      raise ArgumentError if event_name.nil?

      event_name = [event_name] if !event_name.is_a?(Enumerable)
      event_name = event_name.map do |part|
        part = part.to_sym if part.is_a?(String)
        part
      end

      candidates = @all_events.filter | ev |
                   ev[:name] == event_name
    end

    def on(*event_name, &block)
      namespace, event_name = parse_event_name(event_name)

      dot_separated_namespace = namespace.join('.')

      @handlers_by_namespace ||= {}
      @handlers_by_namespace[dot_separated_namespace] ||= {}
      @handlers_by_namespace[dot_separated_namespace][event_name] << block
    end

    def invoke_handlers(event_name)
      namespace, event_name = parse_event_name(event_name)
      dot_separated_namespace = namespace.join('.')

      return unless defined?(@handlers_by_namespace)

      event_handlers = @handlers_by_namespace.dig(
        dot_separated_namespace,
        event_name,
      )

      return unless event_handlers

      event_handlers.each do |block|
        instance_eval(block)
      end
    end
  end
end
