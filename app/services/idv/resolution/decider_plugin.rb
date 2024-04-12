module Idv
  module Resolution
    ##
    # DeciderPlugin looks at an identity resolution run so far and makes a
    # decision as to whether the user has "passed" or not.
    #
    # It records its decision in the `decider` key on the result, e.g.:
    #
    #     decider: {
    #       result: :pass,
    #     }
    #
    # for success or:
    #
    #     decider: {
    #        result: :fail
    #     }
    #
    # for failure.
    #
    # In the case of failure there will also be a `failure_reasons` array
    # containing the names of any checks that failed.
    class DeciderPlugin
      CHECKS = [
        :input_includes_state_id,
        :input_includes_address_of_residence,

        :threatmetrix_ran,
        :threatmetrix_success,

        :instant_verify_ran,
        :instant_verify_address_of_residence_success,
        :instant_verify_state_id_address_success,

        :aamva_ran,
        :aamva_state_id_address_success_or_unsupported_jurisdiction,
      ].freeze

      def call(
        input:,
        result:,
        next_plugin:
      )

        failed_checks = CHECKS.select do |check|
          !send(check, input:, result:)
        rescue
          true
        end

        if failed_checks.empty?
          next_plugin.call(
            decider: {
              result: :pass,
            },
          )
        else
          next_plugin.call(
            decider: {
              result: :fail,
              failed_checks:,
            },
          )
      end
      end

      def aamva_ran(result:, **)
        result[:aamva].present?
      end

      def aamva_state_id_address_success_or_unsupported_jurisdiction(result:, **)
        result[:aamva][:state_id_address].success ||
          result[:aamva][:state_id_address].exception == :unsupported_jurisdiction
      end

      def input_includes_state_id(input:, **)
        input&.state_id.present?
      end

      def input_includes_address_of_residence(input:, **)
        input&.address_of_residence.present?
      end

      def instant_verify_ran(result:, **)
        result[:instant_verify].present?
      end

      def instant_verify_address_of_residence_success(result:, **)
        result[:instant_verify][:address_of_residence]&.success
      end

      def instant_verify_state_id_address_success(result:, **)
        result[:instant_verify][:state_id]&.success
      end

      def threatmetrix_ran(result:, **)
        result[:threatmetrix].present?
      end

      def threatmetrix_success(result:, **)
        result[:threatmetrix].success
      end
    end
  end
end
