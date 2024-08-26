# frozen_string_literal: true

module Proofing
  module Socure
    module IdPlus
      Input = RedactedStruct.new(
        :address1,
        :address2,
        :city,
        :dob,
        :first_name,
        :last_name,
        :middle_name,
        :state,
        :zipcode,
        :phone,
        :email,
        :ssn,
        keyword_init: true,
      ).freeze
    end
  end
end
