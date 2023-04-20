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

      validates_with UspsInPersonProofing::TransliterableValidator,
                     fields: [:first_name, :last_name, :identity_doc_city],
                     reject_chars: /[^A-Za-z\-' ]/,
                     message: ->(invalid_chars) do
                       I18n.t(
                         'in_person_proofing.form.state_id.errors.unsupported_chars',
                         char_list: invalid_chars.join(', '),
                       )
                     end

      validates_with UspsInPersonProofing::TransliterableValidator,
                     fields: [:identity_doc_address1, :identity_doc_address2],
                     reject_chars: /[^A-Za-z0-9\-' .\/#]/,
                     message: ->(invalid_chars) do
                       I18n.t(
                         'in_person_proofing.form.state_id.errors.unsupported_chars',
                         char_list: invalid_chars.join(', '),
                       )
                     end
    end
  end
end
