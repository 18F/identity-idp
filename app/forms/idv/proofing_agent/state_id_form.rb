# frozen_string_literal: true

module Idv
  module ProofingAgent
    class StateIdForm
      include ActiveModel::Validations
      include StateIdValidator

      attr_reader(*STATE_ID_ATTRS)

      def initialize(state_id:)
        STATE_ID_ATTRS.each do |attr|
          instance_variable_set("@#{attr}", state_id[attr])
        end
      end
    end
  end
end
