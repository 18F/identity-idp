class LanguagePickerComponentPreview < BaseComponentPreview
  # @!group Preview
  # @display body_class tablet:bg-primary-darker padding-top-10
  def default
    render(LanguagePickerComponent.new(class: css_class))
  end
  # @!endgroup

  # @display body_class tablet:bg-primary-darker padding-top-10
  def workbench
    render(LanguagePickerComponent.new(class: css_class))
  end

  private

  def css_class
    'margin-top-10 tablet:display-inline-block'
  end
end
