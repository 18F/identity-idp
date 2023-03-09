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
                     fields: [:first_name, :last_name],
                     reject_chars: /[^A-Za-z\-' ]/,
                     message: (proc do |invalid_chars|
                                 I18n.t(
                                   'in_person_proofing.form.state_id.errors.unsupported_chars',
                                   char_list: invalid_chars.join(', '),
                                 )
                               end)
    end
  end
end
