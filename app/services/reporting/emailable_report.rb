# frozen_string_literal: true

module Reporting
  # Represents tabular data and how to render the table in an email body and
  # name it as an attachment
  # @!attribute [rw] table
  #   @return [Array<Array<String>>]
  # @!attribute [rw] filename
  #   @return [String] filename for attachment
  # @!attribute [rw] title
  #   @return [String] title for table in email body
  # @!attribute [rw] float_as_percent
  #   @return [Boolean] whether or not floating point values should be rendered as percents
  # @!attribute [rw] precision
  #   @return [Integer] number of digits of precision for rendering as percent
  EmailableReport = Struct.new(
    :table,
    :filename,
    :subtitle,
    :title,
    :float_as_percent,
    :precision,
  ) do
    alias_method :float_as_percent?, :float_as_percent
  end
end
