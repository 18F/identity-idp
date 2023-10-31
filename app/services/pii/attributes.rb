module Pii
  DEPRECATED_PII_ATTRIBUTES = [
    :otp, # https://github.com/18F/identity-idp/pull/1661
    # Address fields that we might be able to remove. We don't think these were ever used in prod
    :prev_address1, :prev_address2, :prev_city, :prev_state, :prev_zipcode
  ].freeze

  Attributes = RedactedStruct.new(
    :first_name, :middle_name, :last_name,
    # The user's residential address
    :address1, :address2, :city, :state, :zipcode, :same_address_as_id,
    # The address on a user's state-issued ID, which may be different from their residential address
    :identity_doc_address1, :identity_doc_address2, :identity_doc_city, :identity_doc_zipcode,
    # the state that issued the id, which may be different than the state in the state id address
    :state_id_jurisdiction,
    # the state in the state id address, which may not be the state that issued the ID
    :identity_doc_address_state,
    :ssn, :dob, :phone,
    *DEPRECATED_PII_ATTRIBUTES,
    keyword_init: true,
  ) do
    def self.new_from_hash(hash)
      attrs = new
      hash.with_indifferent_access.
        slice(*members).
        each { |key, val| attrs[key] = val }
      attrs
    end

    def self.new_from_json(pii_json)
      return new if pii_json.blank?
      pii = JSON.parse(pii_json, symbolize_names: true)
      new_from_hash(pii)
    end

    def eql?(other)
      to_json == other.to_json
    end

    def ==(other)
      eql?(other)
    end

    private

    def assign_all_members
      self.class.members.each do |member|
        self[member] = self[member]
      end
    end
  end
end
