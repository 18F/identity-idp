# frozen_string_literal: true

module NDS
  # Account-creation step model for the NDS header progress stepper (renders
  # only in the nds layout). Analog of Idv::StepIndicatorConcern, but a plain
  # value module: no page consumes it yet, so it carries no controller wiring.
  # Account has 2 substeps (enter-email 1/2, verify-email 2/2); Security is
  # create-password; Verification is identity verification.
  module AccountCreationSteps
    STEPS = [
      { name: :account },
      { name: :security },
      { name: :verification },
    ].freeze

    SUBSTEP_COUNTS = { account: 2 }.freeze

    module_function

    def steps
      STEPS
    end

    def labels
      STEPS.map { |step| I18n.t("step_indicator.flows.account_creation.#{step[:name]}") }
    end

    def index_for(step)
      STEPS.index { |candidate| candidate[:name] == step.to_sym } ||
        raise(ArgumentError, "unknown account creation step: #{step}")
    end

    # Builds the keyword args for NDS::ProgressComponent for the given step.
    def progress_args(step:, substep: nil)
      name = step.to_sym
      args = { steps: labels, current_step: index_for(name) }
      count = SUBSTEP_COUNTS[name]
      if substep && count
        args[:current_substep] = substep
        args[:substep_count] = count
      end
      args
    end
  end
end
