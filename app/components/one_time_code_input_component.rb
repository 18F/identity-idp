class OneTimeCodeInputComponent < BaseComponent
  attr_reader :form,
              :name,
              :value,
              :maxlength,
              :autofocus,
              :transport,
              :numeric,
              :field_options,
              :tag_options

  alias_method :numeric?, :numeric
  alias_method :autofocus?, :autofocus

  # @param [FormBuilder] form Form builder instance.
  # @param [Symbol] name Field name. Defaults to `:code`.
  # @param [String] value Field value. Defaults to empty.
  # @param [Integer] maxlength Sets maxlength for the field. Defaults to
  # TwoFactorAuthenticatable::DIRECT_OTP_LENGTH
  # @param [Boolean] autofocus Whether the input should be focused on page load. Defaults to
  # `false`.
  # @param [String] transport WebOTP transport method. Defaults to 'sms'.
  # @param [Boolean] numeric if the field should only accept digits. Defaults to true
  # @param [Hash] field_options Additional options to pass to ValidatedFieldComponent
  # @param [Hash] tag_options Additional HTML attributes to add
  def initialize(
    form:,
    name: :code,
    value: nil,
    maxlength: TwoFactorAuthenticatable::DIRECT_OTP_LENGTH,
    autofocus: false,
    transport: 'sms',
    numeric: true,
    field_options: {},
    **tag_options
  )
    @form = form
    @name = name
    @value = value
    @maxlength = maxlength
    @autofocus = autofocus
    @transport = transport
    @numeric = numeric
    @field_options = field_options
    @tag_options = tag_options
  end

  def hint
    if numeric?
      t('components.one_time_code_input.hint.numeric')
    else
      t('components.one_time_code_input.hint.alphanumeric')
    end
  end

  def input_pattern
    if numeric?
      '[0-9]*'
    else
      '[a-zA-Z0-9]*'
    end
  end

  def input_inputmode
    if numeric?
      :numeric
    else
      :text
    end
  end

  def input_css_class
    [*field_options.dig(:input_html, :class), 'one-time-code-input__input']
  end
end
