# frozen_string_literal: true

class OneTimeCodeInputComponent < BaseComponent
  attr_reader :form,
              :name,
              :value,
              :code_length,
              :optional_prefix,
              :autofocus,
              :transport,
              :numeric,
              :field_options,
              :tag_options

  alias_method :numeric?, :numeric
  alias_method :autofocus?, :autofocus

  # @see https://tc39.es/ecma262/#prod-SyntaxCharacter
  JS_REGEXP_SYNTAX_CHARACTER = Regexp.union(%w[^ $ \ . * + ? ( ) [ ] { } |])

  # @param [FormBuilder] form Form builder instance.
  # @param [Symbol] name Field name. Defaults to `:code`.
  # @param [String] value Field value. Defaults to empty.
  # @param [Integer] code_length Expected code length. Defaults to
  # TwoFactorAuthenticatable::DIRECT_OTP_LENGTH
  # @param [String] optional_prefix Optional prefix to allow before code
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
    code_length: TwoFactorAuthenticatable::DIRECT_OTP_LENGTH,
    optional_prefix: '',
    autofocus: false,
    transport: 'sms',
    numeric: true,
    field_options: {},
    **tag_options
  )
    @form = form
    @name = name
    @value = value
    @code_length = code_length
    @optional_prefix = optional_prefix
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

  def input_maxlength
    optional_prefix.size + code_length
  end

  def input_pattern
    "#{input_pattern_prefix}#{input_pattern_character_set}{#{code_length}}"
  end

  def input_pattern_prefix
    "#{regexp_escape_for_js(optional_prefix)}?" if optional_prefix.present?
  end

  def input_pattern_character_set
    if numeric?
      '[0-9]'
    else
      '[a-zA-Z0-9]'
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

  def regexp_escape_for_js(string)
    # `Regexp.escape` escapes more characters than what is considered "special" for JavaScript
    # regular expressions. Browsers may log errors for unexpected escaping of characters.
    string.gsub(JS_REGEXP_SYNTAX_CHARACTER) { |c| Regexp.escape(c) }
  end
end
