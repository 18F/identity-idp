class MemorableDateComponent < BaseComponent
  attr_reader :month, :day, :year, :hint, :label, :form

  alias_method :f, :form
 
  def initialize(month:, day:, year:, hint:, label:, form:, error_messages: {}, **_tag_options)
    @month = month
    @day = day
    @year = year
    @hint = hint
    @label = label
    @form = form
    @error_messages = error_messages
    @tag_options = []
  end

  def error_messages
    # WILLDO handle validation errors
  end
end
