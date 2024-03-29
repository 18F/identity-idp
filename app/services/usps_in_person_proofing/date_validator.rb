# frozen_string_literal: true

module UspsInPersonProofing
  # Validator that can be attached to a form or other model
  # to verify that specific supported fields are comparable to other dates.
  # Since it's a subclass of ComparisonValidator, it share the same options.
  # == Example
  #
  #   validates_with UspsInPersonProofing::DateValidator,
  #     attributes: [:dob],
  #     message: "error",
  #     less_than_or_equal_to: ->(_rec) {
  #         Time.zone.today - IdentityConfig.store.idv_min_age_years.years
  #     }
  #     ....
  #
  class DateValidator < ActiveModel::Validations::ComparisonValidator
    private

    def prepare_value_for_validation(value, _record, _attr_name)
      val_to_date(value)
    rescue
      nil
    end

    # @param [String,Date,#to_hash] param
    # @return [Date]
    # It's caller's responsibility to ensure the param contains required entries
    def val_to_date(param)
      case param
      when String, Date
        DateParser.parse_legacy(param)
      else
        h = param.to_hash.with_indifferent_access
        Date.new(h[:year].to_i, h[:month].to_i, h[:day].to_i)
      end
    end
  end
end
