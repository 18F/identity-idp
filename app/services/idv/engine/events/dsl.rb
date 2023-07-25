# This file defines a domain-specific language (DSL) for configuring events inside an IdvEngine.

module Idv::Engine::Events::Dsl
  class Namespace
    attr_reader :name, :events, :namespaces
    def initialize(name, parent, &block)
      @name = name
      @parent = parent
      @namespaces = []
      @events = []

      instance_eval(&block)
    end

    def method_missing(symbol, *args)
      namespace = namespaces.find { |el| el.name == symbol }
      return namespace if namespace

      event = events.find { |el| el.name == symbol }
      return event if event

      super(symbol, *args)
    end

    def description(value = nil)
      @description = value unless value.nil?
      @description
    end

    def event(name, &block)
      @events << Event.new(name, self, &block)
    end

    def full_name
      if parent
        "#{parent.full_name}.#{name}"
      else
        name.to_s
      end
    end

    def namespace(name, &block)
      @namespaces << Namespace.new(name, self, &block)
    end
  end

  class Event
    attr_reader :name, :namespace

    def initialize(name, namespace)
      @name = name
      @namespace = namespace
    end

    def description(value = nil)
      @description = value unless value.nil?
      @description
    end

    def full_name
      return "#{namespace.full_name}.#{name}"
    end
  end

  def self.included(base)
    base.class_eval do
      # Make a `namespace` method available for defining root namespaces.
      def self.namespace(name, &block)
        @root_namespaces ||= []
        @root_namespaces << Namespace.new(name, nil, &block)
      end

      # When our module is itself included, capture the state of the root namespaces
      # and add helper methods for working with them.
      def self.included(base)
        root_namespaces = @root_namespaces.dup.freeze
        base.class_variable_set(:@@root_namespaces, root_namespaces)

        root_namespaces.each do |namespace|
          base.define_method(namespace.name) { namespace }
        end

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

  module HelperMethods
    def get_event(*event_name)
      og_event_name = event_name.dup
      context = @@root_namespaces || []
      until event_name.empty?
        item = event_name.shift
        next_context_item = context.find { |i| i.name == item }
        raise "Invalid event name: #{og_event_name}" unless next_context_item
        if event_name.empty?
          raise "#{og_event_name} is a namespace, not an event" unless next_context_item.is_a?(Event)
          return next_context_item
        end

        if next_context_item.is_a?(Event)
          raise "#{next_context_item.full_name} is an Event, not a Namespace"
        end

        if event_name.length == 1
          context = next_context_item.events
        else
          context = next_context_item.namespaces
        end
      end
    end

    def on(*event_name, &block)
      event = get_event(*event_name)

      raise "Unknown event: #{event_name}" unless event

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
