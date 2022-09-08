class StepIndicatorComponent < BaseComponent
  attr_reader :current_step, :locale_scope, :tag_options

  def initialize(steps:, current_step:, locale_scope: nil, **tag_options)
    @steps = steps
    @current_step = current_step
    @locale_scope = locale_scope
    @tag_options = tag_options
  end

  def css_class
    ['step-indicator', *tag_options[:class]]
  end

  def steps
    @steps.map { |step| { status: step_status(step), title: step_title(step) }.merge(step) }
  end

  private

  def step_status(step)
    if step[:name] == current_step
      :current
    elsif step_index(step[:name]) < step_index(current_step)
      :complete
    end
  end

  def step_title(step)
    if locale_scope
      t(step[:name], scope: [:step_indicator, :flows, locale_scope])
    else
      step[:title]
    end
  end

  def step_index(name)
    @steps.index { |step| step[:name] == name }.to_i
  end
end
