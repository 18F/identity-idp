# frozen_string_literal: true

# Header progress positions for flows that do **not** already expose domain step
# lists (today: sign-up). IDV uses {Idv::StepIndicatorConcern} via the shared
# step_indicator partial instead — do not mirror IDV routes here.
#
# ## Add a sign-up screen
#
#   flow.map 'users/phone_setup#index', step: 1, substep: 1
#
# `substeps` defaults from the flow's per-step totals (see `substeps:` on
# {.define}). Pass `substeps:` only to override.
#
# ## Position fields
#
# - step:     0-based index into `steps`
# - substep:  1-based counter within the step (optional)
# - substeps: total for the counter (optional; defaults from flow)
# - gate:     :none always; :creation during account creation / multi-MFA
#             (default: :none for step 0, :creation otherwise)
#
class ProgressFlow
  # rubocop:disable Style/MutableConstant -- Data.define returns a class
  Position = Data.define(:flow, :step, :substep, :substeps, :gate) do
    def creation_gated?
      gate == :creation
    end
  end
  # rubocop:enable Style/MutableConstant

  class Definition
    attr_reader :name, :step_keys, :i18n_scope, :step_substeps, :routes

    def initialize(name, step_keys:, i18n_scope:, step_substeps: {})
      @name = name
      @step_keys = step_keys.freeze
      @i18n_scope = i18n_scope
      @step_substeps = normalize_step_substeps(step_substeps).freeze
      @routes = {}
    end

    # @param route_keys [String, Array<String>] "controller/path#action"
    def map(route_keys, step:, substep: nil, substeps: nil, gate: nil)
      # Apply per-step totals only when a substep counter is requested.
      resolved_substeps = substep.nil? ? substeps : (substeps || step_substeps[step])
      validate_position!(step:, substep:, substeps: resolved_substeps)
      resolved_gate = gate || (step.zero? ? :none : :creation)

      Array(route_keys).each do |key|
        raise ArgumentError, "duplicate progress route: #{key}" if routes.key?(key)

        routes[key] = {
          step:,
          substep:,
          substeps: resolved_substeps,
          gate: resolved_gate,
        }.freeze
      end
    end

    def freeze!
      routes.freeze
      freeze
    end

    private

    def normalize_step_substeps(value)
      value.to_h.transform_keys do |key|
        case key
        when Integer then key
        when Symbol, String
          index = step_keys.index(key.to_sym)
          raise ArgumentError, "unknown step for substeps: #{key.inspect}" if index.nil?
          index
        else
          raise ArgumentError, "invalid substeps key: #{key.inspect}"
        end
      end
    end

    def validate_position!(step:, substep:, substeps:)
      unless step.is_a?(Integer) && step >= 0 && step < step_keys.length
        raise ArgumentError, "step #{step.inspect} outside 0...#{step_keys.length}"
      end

      return if substep.nil? && substeps.nil?

      unless substep.is_a?(Integer) && substeps.is_a?(Integer) &&
             substep.between?(1, substeps)
        raise ArgumentError,
              "substep #{substep.inspect}/#{substeps.inspect} must be 1-based within total"
      end
    end
  end

  class << self
    def define(name, steps:, i18n_scope:, substeps: {})
      definition = Definition.new(
        name,
        step_keys: steps,
        i18n_scope:,
        step_substeps: substeps,
      )
      yield definition
      registry[name] = definition.freeze!
      definition
    end

    def registry
      @registry ||= {}
    end

    # @return [ProgressFlow::Position, nil]
    def find(route_key)
      registry.each_value do |flow|
        entry = flow.routes[route_key]
        next unless entry

        return Position.new(
          flow:,
          step: entry[:step],
          substep: entry[:substep],
          substeps: entry[:substeps],
          gate: entry[:gate],
        )
      end
      nil
    end
  end
end

# rubocop:disable Metrics/BlockLength -- route registry reads best as one table
ProgressFlow.define(
  :sign_up,
  steps: %i[create_account secure connect],
  i18n_scope: 'step_indicator.flows.sign_up',
  substeps: {
    create_account: 2,
    secure: 2,
  },
) do |flow|
  # Step 0 — Account (email → password)
  flow.map(
    %w[
      sign_up/registrations#new
      sign_up/registrations#create
      sign_up/emails#show
    ],
    step: 0,
    substep: 1,
  )
  flow.map(
    %w[
      sign_up/passwords#new
      sign_up/passwords#create
    ],
    step: 0,
    substep: 2,
  )
  flow.map('sign_up/cancellations#new', step: 0, substep: 1)
  flow.map(
    %w[
      users/rules_of_use#new
      users/rules_of_use#create
    ],
    step: 0,
    substep: 2,
  )

  # Step 1 — Authentication (primary method → backup)
  flow.map(
    %w[
      users/two_factor_authentication_setup#index
      users/two_factor_authentication_setup#create
      users/webauthn_setup#new
      users/webauthn_setup#confirm
      users/webauthn_platform_recommended#new
      users/webauthn_platform_recommended#create
      users/webauthn_setup_mismatch#show
      users/totp_setup#new
      users/totp_setup#confirm
      users/phone_setup#index
      users/phone_setup#create
      users/piv_cac_authentication_setup#new
      users/piv_cac_authentication_setup#submit_new_piv_cac
      users/piv_cac_authentication_setup#error
      users/piv_cac_recommended#show
      mfa_confirmation#show
      two_factor_authentication/otp_verification#show
      two_factor_authentication/otp_verification#create
    ],
    step: 1,
    substep: 1,
  )
  flow.map(
    %w[
      users/backup_code_setup#index
      users/backup_code_setup#new
      users/backup_code_setup#create
      users/backup_code_setup#confirm_backup_codes
      users/backup_code_setup#refreshed
    ],
    step: 1,
    substep: 2,
  )

  # Step 2 — Verification: not mapped here. IDV uses StepIndicatorConcern
  # via app/views/idv/shared/_step_indicator.html.erb.
end
# rubocop:enable Metrics/BlockLength
