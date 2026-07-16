# frozen_string_literal: true

# Date param helper kept for IDV forms that submit month/day/year fields.
# The USWDS MemorableDate view component was removed in the ADS reskin.
class MemorableDateComponent
  # Extract a memorable date param from a submitted form value
  #
  # @param [Hash] date
  # @option date [String] month
  # @option date [String] day
  # @option date [String] year
  # @return [String,nil] The formatted date, or nil if the param cannot be converted
  def self.extract_date_param(date)
    if date.instance_of?(String) || date.empty?
      nil
    else
      formatted_date = [
        date&.[](:year),
        date&.[](:month)&.rjust(2, '0'),
        date&.[](:day)&.rjust(2, '0'),
      ].join '-'
      formatted_date if /^\d{4}-\d{2}-\d{2}$/.match? formatted_date
    end
  end
end
