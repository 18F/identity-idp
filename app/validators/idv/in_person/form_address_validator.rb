module Idv
  module InPerson
    module FormAddressValidator
      extend ActiveSupport::Concern
      include Idv::FormAddressValidator

      included do
        validates :same_address_as_id,
                  presence: true

        validates_with UspsInPersonProofing::TransliterableValidator,
                       fields: [:city],
                       reject_chars: /[^A-Za-z\-' ]/,
                       message: (proc do |invalid_chars|
                         I18n.t(
                           'in_person_proofing.form.address.errors.unsupported_chars',
                           char_list: invalid_chars.join(', '),
                         )
                       end)

        validates_with UspsInPersonProofing::TransliterableValidator,
                       fields: [:address1, :address2],
                       reject_chars: /[^A-Za-z0-9\-' .\/#]/,
                       message: (proc do |invalid_chars|
                         I18n.t(
                           'in_person_proofing.form.address.errors.unsupported_chars',
                           char_list: invalid_chars.join(', '),
                         )
                       end)
      end
    end
  end
end
