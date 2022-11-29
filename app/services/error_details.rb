class ErrorDetails
  attr_reader :details

  def initialize(details)
    @details = details
  end

  def flatten
    details.transform_values { |errors| errors.pluck(:error) }
  end
end
