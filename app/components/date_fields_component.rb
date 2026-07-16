# frozen_string_literal: true

# Compact month/day/year fieldset used by IDV date inputs.
class DateFieldsComponent < BaseComponent
  attr_reader :form, :attribute, :legend, :hint, :month, :day, :year, :error_message,
              :autocomplete_prefix, :hint_id

  def initialize(
    form:,
    attribute:,
    legend:,
    hint: nil,
    month: nil,
    day: nil,
    year: nil,
    error_message: nil,
    autocomplete_prefix: nil,
    hint_id: nil
  )
    @form = form
    @attribute = attribute
    @legend = legend
    @hint = hint
    @month = month
    @day = day
    @year = year
    @error_message = error_message
    @autocomplete_prefix = autocomplete_prefix
    @hint_id = hint_id
  end

  def autocomplete_for(part)
    return if autocomplete_prefix.blank?

    "#{autocomplete_prefix}-#{part}"
  end
end
