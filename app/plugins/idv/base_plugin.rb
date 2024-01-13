module Idv
  class BasePlugin
    def step_completed(step:, **rest)
      return unless @step_completed_handlers && @step_completed_handlers[step]
      @step_completed_handlers[step].each do |block|
        block.call(**rest)
      end
    end

    def step_started(step:, **rest)
      return unless @step_started_handlers && @step_started_handlers[step]
      @step_started_handlers[step].each do |block|
        block.call(**rest)
      end
    end

    def self.on_step_completed(
        step,
        &block
      )
      @step_completed_handlers ||= {}
      @step_completed_handlers[step] ||= []
      @step_completed_handlers[step].append(block)
    end

    def self.on_step_started(
      step,
      &block
    )
      @step_started_handlers ||= {}
      @step_started_handlers[step] ||= []
      @step_started_handlers[step].append(block)
    end
  end
end
