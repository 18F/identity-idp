module Idv
  class CacForm
    include ActiveModel::Model
    include FormProfileValidator

    PROFILE_ATTRIBUTES = [
      :first_name, :last_name, :address1, :address2, :city, :state, :zipcode, :ssn, :dob, :phone
      # *Pii::Attributes.members,
    ].freeze

    attr_reader :user
    attr_accessor(*PROFILE_ATTRIBUTES)

    def self.model_name
      ActiveModel::Name.new(self, nil, 'Profile')
    end

    def initialize(user:, previous_params:)
      @user = user
      consume_params(previous_params) if previous_params.present?
    end

    def submit(params)
      consume_params(params)

      FormResponse.new(success: valid?, errors: errors.messages)
    end

    private

    def consume_params(params)
      params.each do |key, value|
        raise_invalid_profile_parameter_error(key) unless PROFILE_ATTRIBUTES.include?(key.to_sym)
        send("#{key}=", value)
      end
    end

    def raise_invalid_profile_parameter_error(key)
      raise ArgumentError, "#{key} is an invalid profile attribute"
    end
  end
end
