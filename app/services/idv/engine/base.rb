module Idv::Engine
  class Base
    include Events

    def self.on(event_name, &block)
      event_name = event_name.to_sym

      raise "Invalid event name: #{event_name}" unless Events::ALL.include?(event_name)

      @@handlers ||= {}
      @@handlers[event_name] ||= []
      @@handlers[event_name] << block
    end

    def initialize
    end

    # @return [Verification] The current verification.
    def verification
      @verification ||= build_verification
    end

    protected

    def build_verification
      raise 'build_verification not implemented'
    end

    def handle_event(event_name, params = nil)
      invalidate_cache!

      if self.class.class_variable_defined?(:@@handlers)
        handlers = self.class.class_variable_get(:@@handlers)
        if handlers && handlers[event_name]
          handlers[event_name].each do
            instance_exec(params, &block)
          end
        end
      end
    end

    def invalidate_cache!
      @verification = nil
    end
  end
end
