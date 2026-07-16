# frozen_string_literal: true

class InputComponentPreview < BaseComponentPreview
  # @!group Preview
  def preview
  end
  # @!endgroup

  # @param label text
  # @param type select [text,email,tel,password,date]
  # @param value text
  # @param floating_label toggle
  # @param country_selector toggle
  # @param selected_country text
  # @param error toggle
  # @param readonly toggle
  # @param disabled toggle
  def workbench(
    label: 'Email address',
    type: :email,
    value: '',
    floating_label: true,
    country_selector: false,
    selected_country: 'US',
    error: false,
    readonly: false,
    disabled: false
  )
  end
end
