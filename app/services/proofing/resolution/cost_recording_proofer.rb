# frozen_string_literal: true

module Proofing
  module Resolution
    class CostRecordingProofer
      attr_reader :proofer, :sp_cost_token, :current_sp

      def initialize(proofer:, sp_cost_token:, current_sp:)
        @proofer = proofer
        @sp_cost_token = sp_cost_token
        @current_sp = current_sp
      end

      def proof(applicant)
        result = proofer.proof(applicant)

        Db::SpCost::AddSpCost.call(
          current_sp,
          sp_cost_token,
          transaction_id: result.transaction_id,
        )

        result
      end
    end
  end
end
