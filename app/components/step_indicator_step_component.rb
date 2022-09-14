class StepIndicatorStepComponent < BaseComponent
  attr_reader :title, :status, :tag_options

  def initialize(title: nil, status: nil, **tag_options)
    @title = title
    @status = status || :not_complete
    @tag_options = tag_options
  end

  def css_class
    classes = ['step-indicator__step']
    classes << 'step-indicator__step--current' if status == :current
    classes << 'step-indicator__step--complete' if status == :complete
    classes
  end
end
