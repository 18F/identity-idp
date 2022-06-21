module Idv
  module FormStateIdValidator
    extend ActiveSupport::Concern

    included do
      validates :first_name,
                :last_name,
                :dob,
                :state_id_jurisdiction,
                :state_id_number,
                presence: true
    end
  end
end
