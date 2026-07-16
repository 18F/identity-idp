# frozen_string_literal: true

class InputOtpComponent < BaseComponent
  JS_REGEXP_SYNTAX_CHARACTER = Regexp.union(%w[^ $ \ . * + ? ( ) [ ] { } |]).freeze
  VALID_TYPES = [:text, :password].freeze
  VALID_PUSH_PASSWORD_MANAGER_STRATEGIES = [:increase_width, :none].freeze

  attr_reader :form,
              :name,
              :value,
              :length,
              :groups,
              :numeric,
              :optional_prefix,
              :autofocus,
              :transport,
              :type,
              :separator,
              :push_password_manager_strategy,
              :field_class,
              :field_data,
              :inputmode,
              :autocomplete,
              :required,
              :disabled,
              :readonly,
              :input_options

  alias_method :numeric?, :numeric
  alias_method :autofocus?, :autofocus
  alias_method :required?, :required
  alias_method :disabled?, :disabled
  alias_method :readonly?, :readonly

  validates_numericality_of :length, only_integer: true, greater_than: 0
  validates_inclusion_of :type, in: VALID_TYPES
  validates_inclusion_of :push_password_manager_strategy,
                         in: VALID_PUSH_PASSWORD_MANAGER_STRATEGIES
  validate :validate_groups
  validate :validate_optional_prefix

  def initialize(
    form:,
    name: :code,
    label: nil,
    value: nil,
    length: TwoFactorAuthenticatable::DIRECT_OTP_LENGTH,
    groups: nil,
    numeric: true,
    optional_prefix: '',
    autofocus: false,
    transport: 'sms',
    type: :text,
    separator: nil,
    push_password_manager_strategy: :increase_width,
    hint: nil,
    error_message: nil,
    field_class: nil,
    field_data: {},
    inputmode: nil,
    autocomplete: 'one-time-code',
    required: true,
    disabled: false,
    readonly: false,
    **input_options
  )
    @form = form
    @name = name
    @label = label
    @value = value
    @length = length
    @groups = groups.nil? ? [length] : groups
    @numeric = numeric
    @optional_prefix = optional_prefix.to_s
    @autofocus = autofocus
    @transport = transport
    @type = type&.to_sym
    @separator = separator
    @push_password_manager_strategy = push_password_manager_strategy&.to_sym
    @hint = hint
    @error_message = error_message
    @field_class = field_class
    @field_data = field_data
    @inputmode = inputmode
    @autocomplete = autocomplete
    @required = required
    @disabled = disabled
    @readonly = readonly
    @input_options = input_options
  end

  def root_data
    {
      length:,
      numeric: numeric?,
      optional_prefix:,
      transport:,
      push_password_manager_strategy:,
    }.compact
  end

  def label
    @label || t('components.one_time_code_input.label')
  end

  def field_classes
    ['ads-input', 'ads-input-otp', field_class].compact.join(' ')
  end

  def input_classes
    ['ads-input__control', 'ads-input-otp__input', *Array(input_options[:class])].join(' ')
  end

  def separator_classes
    [
      'ads-input-otp__separator',
      ('ads-input-otp__separator--text' if separator.present?),
    ].compact.join(' ')
  end

  def input_html_options
    input_options.except(:class, :aria, :data, :id).merge(
      aria: input_aria,
      autocomplete:,
      autofocus: autofocus?,
      class: input_classes,
      data: input_options[:data].to_h.merge(ads_input_otp_input: true),
      disabled: disabled?,
      id: input_id,
      inputmode: input_inputmode,
      maxlength: input_maxlength,
      name: input_name,
      pattern: input_pattern,
      readonly: readonly?,
      required: required?,
      type:,
      value: input_value,
    )
  end

  def input_id
    input_options[:id].presence || form.field_id(name)
  end

  def input_name
    form.field_name(name)
  end

  def input_value
    return value unless value.nil?
    return unless form.object.respond_to?(name)

    form.object.public_send(name)
  end

  def input_maxlength
    optional_prefix.size + length
  end

  def input_pattern
    "#{input_pattern_prefix}#{input_pattern_character_set}{#{length}}"
  end

  def input_pattern_prefix
    "(?:#{regexp_escape_for_js(optional_prefix)})?" if optional_prefix.present?
  end

  def input_pattern_character_set
    numeric? ? '[0-9]' : '[a-zA-Z0-9]'
  end

  def input_inputmode
    inputmode || (numeric? ? :numeric : :text)
  end

  def hint_text
    return @hint unless @hint.nil?

    if numeric?
      t('components.one_time_code_input.hint.numeric')
    else
      t('components.one_time_code_input.hint.alphanumeric')
    end
  end

  def has_hint?
    hint_text.present?
  end

  def error_id
    "#{input_id}_ads_error"
  end

  def hint_id
    "#{input_id}_ads_hint"
  end

  def error_message
    return @error_message if @error_message.present?
    return unless form.object.respond_to?(:errors) && form.object.errors.key?(name)

    form.object.errors[name].first
  end

  def input_aria
    aria = input_options[:aria].to_h.transform_keys(&:to_sym)
    describedby = [aria[:describedby]]
    describedby << hint_id if has_hint?
    describedby << error_id if error_message.present?

    aria.merge(
      describedby: describedby.flatten.compact.join(' ').presence,
      invalid: aria_invalid?,
    ).compact
  end

  def aria_invalid?
    return true if error_message.present?

    ActiveModel::Type::Boolean.new.cast(input_options[:aria].to_h.with_indifferent_access[:invalid])
  end

  def regexp_escape_for_js(string)
    string.gsub(JS_REGEXP_SYNTAX_CHARACTER) { |character| Regexp.escape(character) }
  end

  private

  def validate_groups
    unless groups.is_a?(Array) && groups.all? { |group| group.is_a?(Integer) && group.positive? }
      errors.add(:groups, :invalid_group_length, message: 'must contain positive integers')
      return
    end

    return unless valid_length?
    return if groups.sum == length

    errors.add(:groups, :invalid_group_sum, message: 'must sum to length')
  end

  def validate_optional_prefix
    return unless valid_length?

    if optional_prefix.present? && optional_prefix.match?(valid_code_characters_pattern)
      errors.add(
        :optional_prefix,
        :ambiguous,
        message: 'must include a character outside the code character set',
      )
    end
    return if optional_prefix.length < length

    errors.add(:optional_prefix, :too_long, message: 'must be shorter than length')
  end

  def valid_length?
    length.is_a?(Integer) && length.positive?
  end

  def valid_code_characters_pattern
    numeric? ? /\A[0-9]+\z/ : /\A[a-zA-Z0-9]+\z/
  end
end
