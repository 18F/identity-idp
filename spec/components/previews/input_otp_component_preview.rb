# frozen_string_literal: true

class InputOtpComponentPreview < BaseComponentPreview
  # @!group Preview
  def states
  end
  # @!endgroup

  # @display form true
  # @param value text
  # @param length number
  # @param numeric toggle
  # @param optional_prefix text
  # @param password toggle
  def workbench(
    value: '',
    length: 6,
    numeric: true,
    optional_prefix: '',
    password: false
  )
    render InputOtpComponent.new(
      form: form_builder,
      value:,
      length:,
      numeric:,
      optional_prefix:,
      type: password ? :password : :text,
    )
  end
end
