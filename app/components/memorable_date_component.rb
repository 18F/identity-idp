##
# Provides a component that accepts a date using the inputs specified
# by USWDS here: https://designsystem.digital.gov/components/memorable-date/
#
# This treats the month, day, and year as nested fields to allow for various
# uses of the component. Translate the fields in the controller (or equivalent)
# if you need them to represent a single value.
#
# The errors for this component are configurable via +error_messages+, and you may
# include custom min/max validations via +range_errors+.
class MemorableDateComponent < BaseComponent
  attr_reader :name, :month, :day, :year, :required, :hint, :label, :form, :tag_options

  alias_method :f, :form

  ##
  # @param [String] name Field name for hash containing month, day, and year
  # @param [String] hint Additional Hint to show to the user
  # @param [String] label Label for field
  # @param [String] form Form that this field belongs to
  # @param [String] month Starting value for month
  # @param [String] day Starting value for day
  # @param [String] year Starting value for year
  # @param [Boolean] required Whether this field is required
  # @param [Date,#to_date] min Minimum allowed date, inclusive
  # @param [Date,#to_date] max Maximum allowed date, inclusive
  # @param [Hash<Symbol,String>] error_messages Array of mappings of error states to messages
  # @param [Array<Hash>] range_errors Array of custom range errors
  # @option range_errors [Date,#to_date] :min Minimum value for range check
  # @option range_errors [Date,#to_date] :max Maximum value for range check
  # @option range_errors [String] :message Error message to display if range check fails
  def initialize(
    name:, hint:, label:, form:,
    month: nil,
    day: nil,
    year: nil,
    required: false,
    min: nil,
    max: nil,
    error_messages: {},
    range_errors: [],
    **tag_options
  )
    @name = name
    @month = month
    @day = day
    @year = year
    @required = required
    @min = min
    @max = max
    @hint = hint
    @label = label
    @form = form
    @tag_options = tag_options
    @error_messages = error_messages
    @range_errors = range_errors
  end

  def self.scripts
    super + ValidatedFieldComponent.scripts
  end

  # Get error messages to be provided to the component.
  # Includes both a hash lookup for general error messages
  # and an array lookup for custom range error messages.
  def error_messages
    {
      'error_messages' => generate_error_messages(label, @min, @max, @error_messages),
      'range_errors' => @range_errors.map do |err|
        new_err = {
          message: err[:message],
        }
        new_err[:min] = convert_date err[:min] if !err[:min].blank?
        new_err[:max] = convert_date err[:max] if !err[:max].blank?
        new_err
      end,
    }
  end

  # Get min date as a string like 1892-01-23
  def min
    convert_date @min
  end

  # Get max date as a string like 1892-01-23
  def max
    convert_date @max
  end

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

  private

  # Convert a Date or date-like value to a string like 1892-01-23
  def convert_date(date)
    date.to_date.to_s if date.respond_to?(:to_date)
  end

  # Convert a Date or date-like value to a long-form localized date string
  def i18n_long_format(date)
    if date.respond_to?(:to_date)
      # i18n-tasks-use t('date.formats.long')
      I18n.l(date.to_date, format: :long)
    end
  end

  def has_errors?
    form.object.respond_to?(:errors) && form.object.errors.key?(name)
  end

  def error_msg
    form.object.errors[name]&.first
  end

  # Configure default generic error messages for component,
  # then integrate any overrides
  def generate_error_messages(label, min, max, override_error_messages)
    base_error_messages = {
      missing_month_day_year: t(
        'components.memorable_date.errors.missing_month_day_year',
        label:,
      ),
      missing_month_day: t('components.memorable_date.errors.missing_month_day'),
      missing_month_year: t('components.memorable_date.errors.missing_month_year'),
      missing_day_year: t('components.memorable_date.errors.missing_day_year'),
      missing_month: t('components.memorable_date.errors.missing_month'),
      missing_day: t('components.memorable_date.errors.missing_day'),
      missing_year: t('components.memorable_date.errors.missing_year'),
      invalid_month: t('components.memorable_date.errors.invalid_month'),
      invalid_day: t('components.memorable_date.errors.invalid_day'),
      invalid_year: t('components.memorable_date.errors.invalid_year'),
      invalid_date: t('components.memorable_date.errors.invalid_date'),
    }
    if label && min
      base_error_messages[:range_underflow] =
        t(
          'components.memorable_date.errors.range_underflow', label:,
                                                              date: i18n_long_format(min)
        )
    end

    if label && max
      base_error_messages[:range_overflow] =
        t(
          'components.memorable_date.errors.range_overflow', label:,
                                                             date: i18n_long_format(max)
        )
    end

    if label && min && max
      base_error_messages[:outside_date_range] =
        t(
          'components.memorable_date.errors.outside_date_range',
          label:,
          min: i18n_long_format(min),
          max: i18n_long_format(max),
        )
    end

    if override_error_messages
      {
        **base_error_messages,
        **override_error_messages,
      }
    else
      base_error_messages
    end
  end
end
