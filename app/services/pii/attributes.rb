module Pii
  DEPRECATED_PII_ATTRIBUTES = [
    :otp, # https://github.com/18F/identity-idp/pull/1661
  ].freeze

  Attributes = RedactedStruct.new(
    :first_name,
    :middle_name,
    :last_name,
    :address1,
    :address2,
    :city,
    :state,
    :zipcode,
    :same_address_as_id,
    :ssn,
    :dob,
    :phone,
    :prev_address1,
    :prev_address2,
    :prev_city,
    :prev_state,
    :prev_zipcode,
    *DEPRECATED_PII_ATTRIBUTES,
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

    def initialize(*args)
      super
      assign_all_members
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
