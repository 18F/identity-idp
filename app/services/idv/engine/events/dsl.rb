module Idv::Engine::Events::Dsl
  def self.included(base)
    base.extend(DslMethods)
  end

  module HelperMethods
    def event_namespaces
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

  module DslMethods
    def included(base)
      # When the DSL module is itself included, add some helper methods
      base.extend(HelperMethods)

      # Add methods for each event
      @all_events.each do |event|
      end
    end

    def description(desc)
      raise 'description  must be inside an event block' unless @current_event
      raise "multiple descriptions for event #{current_event[:name]}" if @current_event[:description]
      puts "description self is #{self.inspect}"
      puts "self.class is #{self.class}"
      @current_event[:description] = desc
    end

    def event(name, &block)
      name = name.to_sym if name.is_a?(String)
      raise 'name must be a symbol or string' if !name.is_a?(Symbol)

      current_namespace = @namespace_stack.last
      raise "#{name} event must be added to a namespace" unless current_namespace

      if current_namespace[:events][name]
        raise "Event #{name} already defined for namespace #{current_namespace[:full_name]}"
      end

      @current_event = {
        name: name,
        full_name: "#{current_namespace[:full_name]}.#{name}",
      }

      current_namespace[:events][name] = @current_event

      @all_events ||= []
      @all_events << @current_event

      instance_eval(&block)

      raise "Event #{@current_event[:full_name]} is missing description" unless @current_event[:description]
    ensure
      @current_event = nil
    end

    def namespace(name, &block)
      @namespaces ||= []
      @namespace_stack ||= []

      name = name.to_sym if name.is_a?(String)
      raise 'name must be a symbol or string' if !name.is_a?(Symbol)

      current_namespace = @namespace_stack.last
      new_namespace = nil

      if current_namespace
        new_namespace = current_namespace[:namespaces].find { |n| n[:name] == name }
      end

      if !new_namespace
        new_namespace = {
          name: name,
          full_name: "#{current_namespace ? "#{current_namespace[:full_name]}." : ""}#{name}",
          events: {},
          namespaces: [],
        }
        if current_namespace
          current_namespace[:namespaces] << new_namespace
        else
          @namespaces << new_namespace
        end
      end

      @namespace_stack << new_namespace

      begin
        instance_eval(&block)
      ensure
        @namespace_stack.pop
      end
    end

    def payload(payload = nil)
      raise 'payload must be inside an event block' unless @current_event
      raise "multiple payloads for event #{@current_event[:name]}" if @current_event[:payload]
      @current_event[:payload] = payload
    end
  end
end
