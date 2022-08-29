class MemorableDateComponent < BaseComponent
  attr_reader :month, :day, :year, :required, :hint, :label, :form

  alias_method :f, :form

  def initialize(
    month:,
    day:,
    year:,
    required:,
    hint:,
    label:,
    form:,
    min: nil,
    max: nil,
    error_messages: {},
    range_errors: [],
    **_tag_options
  )
    @month = month
    @day = day
    @year = year
    @required = required
    @min = min
    @max = max
    @hint = hint
    @label = label
    @form = form
    @tag_options = []
    @error_messages = error_messages
    @range_errors = range_errors
  end

  def error_messages
    {
      'error_messages' => generate_error_messages(label, min, max, @error_messages),
      'range_errors' => @range_errors.map do |err|
        new_err = {
          message: err[:message],
        }
        new_err['min'] = convert_date err[:min] if !err[:min].blank?
        new_err['max'] = convert_date err[:max] if !err[:max].blank?
        new_err
      end,
    }
  end

  def min
    convert_date @min
  end

  def max
    convert_date @max
  end

  private

  # Helper function to allow usages to use Date objects directly
  def convert_date date
    if date.instance_of? Date
      I18n.l(date, format: :long)
    elsif date.blank?
      nil
    else
      date.to_s
    end
  end

  def generate_error_messages(label, min, max, override_error_messages)
    base_error_messages = {
      'missing_month_day_year' => t(
        'simple_form.memorable_date.errors.missing_month_day_year',
        label: label,
      ),
      'missing_month_day' => t('simple_form.memorable_date.errors.missing_month_day'),
      'missing_month_year' => t('simple_form.memorable_date.errors.missing_month_year'),
      'missing_day_year' => t('simple_form.memorable_date.errors.missing_day_year'),
      'invalid_month' => t('simple_form.memorable_date.errors.invalid_month'),
      'invalid_day' => t('simple_form.memorable_date.errors.invalid_day'),
      'invalid_year' => t('simple_form.memorable_date.errors.invalid_year'),
      'invalid_date' => t('simple_form.memorable_date.errors.invalid_date'),
    }
    if label && min
      base_error_messages['range_underflow'] =
        t('simple_form.memorable_date.errors.range_underflow', label: label, date: min)
    end

    if label && max
      base_error_messages['range_overflow'] =
        t('simple_form.memorable_date.errors.range_overflow', label: label, date: max)
    end

    if label && min && max
      base_error_messages['outside_date_range'] =
        t('simple_form.memorable_date.errors.outside_date_range', label: label, min: min, max: max)
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
