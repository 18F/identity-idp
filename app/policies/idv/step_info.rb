# frozen_string_literal: true

module Idv
  class StepInfo
    include ActiveModel::Validations

    attr_reader :key, :controller, :action, :next_steps, :preconditions, :undo_step

    validates :controller, presence: true
    validates :action, presence: true
    validate :next_steps_validation, :preconditions_validation, :undo_step_validation

    def initialize(
      key:,
      controller:,
      next_steps:,
      preconditions:,
      undo_step:,
      action: :show
    )
      @key = key
      @controller = Idv::StepInfo.full_controller_name(controller)
      @next_steps = next_steps
      @preconditions = preconditions
      @undo_step = undo_step
      @action = action

      raise ArgumentError unless valid?
    end

    def self.full_controller_name(controller)
      # Need an absolute path for url_for if controller is in a different module
      "/#{controller.name.underscore.gsub('_controller', '')}"
    end

    def next_steps_validation
      unless next_steps.is_a?(Array)
        errors.add(:next_steps, type: :invalid_argument, message: 'next_steps must be an Array')
      end
    end

    def preconditions_validation
      unless preconditions.is_a?(Proc)
        errors.add(:preconditions, type: :invalid_argument, message: 'preconditions must be a Proc')
      end
    end

    def undo_step_validation
      unless undo_step.is_a?(Proc)
        errors.add(:undo_step, type: :invalid_argument, message: 'undo_step must be a Proc')
      end
    end
  end
end
