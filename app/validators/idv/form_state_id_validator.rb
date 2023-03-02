module Idv
  module FormStateIdValidator
    extend ActiveSupport::Concern
    include Idv::InPerson::FormTransliterableValidator

    included do
      validates :first_name,
                :last_name,
                :dob,
                :state_id_jurisdiction,
                :state_id_number,
                presence: true

      transliterate :first_name, :last_name
    end
  end
end
