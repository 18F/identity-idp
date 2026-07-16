# frozen_string_literal: true

# ADS checkbox control states (Figma 1724:742). Styles override `.ads-checkbox*`.
class CheckboxPreview < BaseComponentPreview
  # @!group Preview
  def preview
  end
  # @!endgroup

  # @param label text
  # @param checked toggle
  # @param error toggle
  # @param disabled toggle
  def workbench(
    label: 'Label',
    checked: false,
    error: false,
    disabled: false
  )
  end
end
