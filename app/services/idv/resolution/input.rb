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

      # Converts data from...some other form...into an Input
      def self.from_pii(pii)
        pii_from_doc, address, ssn = separate_pii(pii)

        state_id = pii_from_doc ? StateId.from_pii_from_doc(**pii_from_doc) : nil
        address_of_residence = address ? Address.new(**address) : nil
        other = ssn ? OtherAttributes.new(ssn:) : nil

        Input.new(
          state_id:,
          address_of_residence:,
          other:,
        )
      end

      def self.separate_pii(pii)
        # The goal of this method is to take a pii-like data structure and
        # separate out the components.

        pii = pii.symbolize_keys

        # pii_from_user (IPP) will have PII fields from the state ID stored
        # as identity_doc_* keys.
        looks_like_pii_from_user = %i[
          identity_doc_address1
          identity_doc_city
          identity_doc_zipcode
          identity_doc_address_state
        ].all? { |key| pii[key].present? }

        same_address_as_id =
          pii[:same_address_as_id] == 'true' || pii[:same_address_as_id] == true

        pii_from_doc = pii.slice(
          :first_name,
          :middle_name,
          :last_name,
          :dob,
          :address1,
          :address2,
          :city,
          :state,
          :zipcode,
          :state_id_jurisdiction,
          :state_id_number,
          :state_id_type,
        )
        address = pii.slice(
          :address1,
          :address2,
          :city,
          :state,
          :zipcode,
        )
        ssn = pii[:ssn]

        if looks_like_pii_from_user

          pii_from_doc[:address1] = pii[:identity_doc_address1]
          pii_from_doc[:address2] = pii[:identity_doc_address2]
          pii_from_doc[:city] = pii[:identity_doc_city]
          pii_from_doc[:state] = pii[:identity_doc_address_state]
          pii_from_doc[:zipcode] = pii[:identity_doc_zipcode]

          if same_address_as_id
            # User has said that their residential address matches what's on their id.
            address = pii_from_doc.slice(
              :address1,
              :address2,
              :city,
              :state,
              :zipcode,
            )
          end

        end

        [pii_from_doc, address, ssn]
      end
    end.freeze
  end
end
