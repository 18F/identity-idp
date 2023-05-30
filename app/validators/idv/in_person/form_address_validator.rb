module Idv
  module InPerson
    module FormAddressValidator
      extend ActiveSupport::Concern
      include Idv::FormAddressValidator

      included do
        validates :same_address_as_id,
                  presence: true,
                  unless: :capture_secondary_id_enabled?

        validates_with UspsInPersonProofing::TransliterableValidator,
                       fields: [:city],
                       reject_chars: /[^A-Za-z\-' ]/,
                       message: ->(invalid_chars) do
                         I18n.t(
                           'in_person_proofing.form.address.errors.unsupported_chars',
                           char_list: invalid_chars.join(', '),
                         )
                       end

        validates_with UspsInPersonProofing::TransliterableValidator,
                       fields: [:address1, :address2],
                       reject_chars: /[^A-Za-z0-9\-' .\/#]/,
                       message: ->(invalid_chars) do
                         I18n.t(
                           'in_person_proofing.form.address.errors.unsupported_chars',
                           char_list: invalid_chars.join(', '),
                         )
                       end
      end
    end
  end
end
