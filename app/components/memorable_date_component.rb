class MemorableDateComponent < BaseComponent
  attr_reader :month, :day, :year, :required, :min, :max, :hint, :label, :form, :error_messages

  alias_method :f, :form

  def initialize(month:, day:, year:, required:, hint:, label:, form:, min: nil, max: nil, error_messages: {}, range_errors: [], **_tag_options)
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
    @error_messages = {
      'error_messages' => generate_error_messages(label, min, max, error_messages),
      'range_errors' => range_errors,
    }
  end

  private

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
        t('simple_form.memorable_date.errors.range_underflow', label: label, min: min)
    end

    if label && max
      base_error_messages['range_overflow'] =
        t('simple_form.memorable_date.errors.range_overflow', label: label, max: max)
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
