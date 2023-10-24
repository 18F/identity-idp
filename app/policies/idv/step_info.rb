# frozen_string_literal: true

module Idv
  class StepInfo
    include ActiveModel::Validations

    attr_reader :controller, :action, :next_steps, :requirements

    # validates :controller, presence: true
    # validates :action, presence: true
    validate :next_steps_validation, :requirements_validation

    def initialize(controller:, next_steps:, requirements:, action: :show)
      @controller = controller
      @action = action
      @next_steps = next_steps
      @requirements = requirements

      raise ArgumentError unless valid?
    end

    def next_steps_validation
      unless next_steps.is_a?(Array)
        errors.add(:next_steps, type: :invalid_argument, message: 'next_steps must be an Array')
      end
    end

    def requirements_validation
      unless requirements.is_a?(Proc)
        errors.add(:requirements, type: :invalid_argument, message: 'requirements must be a Proc')
      end
    end
  end
end
