# frozen_string_literal: true

module Idv
  module Resolution
    Address = Data.define(
      :address1,
      :address2,
      :city,
      :state,
      :zipcode,
    ) do
      def initialize(
        address2: nil, **rest
      )
        super(address2:, **rest)
      end
    end.freeze

    # Captures PII attributes contained in a state-issued identity document
    # (that is, a drivers license or state ID).
    StateId = Data.define(
      :type,
      :number,
      :issuing_jurisdiction,
      :first_name,
      :middle_name,
      :last_name,
      :address,
      :dob,
    ) do
      # Converts a pii_from_doc structure into a StateId
      def self.from_pii_from_doc(pii_from_doc)
        StateId.new(
          type: pii_from_doc[:state_id_type],
          number: pii_from_doc[:state_id_number],
          issuing_jurisdiction: pii_from_doc[:state_id_jurisdiction],
          first_name: pii_from_doc[:first_name],
          middle_name: pii_from_doc[:middle_name],
          last_name: pii_from_doc[:last_name],
          dob: pii_from_doc[:dob],
          address: Address.new(
            **pii_from_doc.slice(
              :address1,
              :address2,
              :city,
              :state,
              :zipcode,
            ),
          ),
        )
      end

      # Converts a StateId to a pii_from_doc structure
      def to_pii_from_doc
        {
          state_id_type: type,
          state_id_number: number,
          state_id_jurisdiction: issuing_jurisdiction,
          first_name:,
          middle_name:,
          last_name:,
          dob:,
          **address.to_h,
        }
      end
    end.freeze

    OtherAttributes = Data.define(
      :ssn,
    ).freeze

    Input = Data.define(
      :state_id,
      :address_of_residence,
      :other,
    ) do
      def initialize(
        state_id: nil,
        address_of_residence: nil,
        other: nil
      )
        super(state_id:, address_of_residence:, other:)
      end

      # Convert data from an idv_session into an Input.
      def self.from_idv_session(
        pii_from_doc: nil,
        pii_from_user: nil,
        ssn: nil,
        **_kwargs
      )

        state_id = pii_from_doc ? StateId.from_pii_from_doc(**pii_from_doc) : nil

        address_of_residence = nil
        if pii_from_user
          address_of_residence = Address.new(
            **pii_from_user.slice(
              :address1,
              :address2,
              :city,
              :state,
              :zipcode,
            ),
          )
        end

        other = nil
        if ssn
          other = OtherAttributes.new(
            ssn:,
          )
        end

        Input.new(
          state_id:,
          address_of_residence:,
          other:,
        )
      end
    end.freeze
  end
end
