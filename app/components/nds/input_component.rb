# frozen_string_literal: true

module NDS
  # Net-new NDS enhanced text/phone/password input (NDS bucket only). Emits the
  # usa-input contract: usa-input(+--phone/--password) wrapping
  # usa-input__control(--floating/--phone/--password), usa-input__shell /
  # usa-input__phone-shell with __country-shell/__country/__country-value/
  # __country-icon, usa-input__floating-label, a usa-input__toggle password
  # button, and usa-input__error/__error-inner (data-nds-error, id _nds_error).
  # Icons are inlined SVGs (no IconComponent dependency) carrying the
  # usa-input__country-icon and data-nds-password-icon-show/hide CSS hooks. The
  # default experience keeps its existing inputs; this variant is NDS-only.
  class InputComponent < BaseComponent
    # Matches server valid_email rule: domain must have 2+ labels (not user@example).
    EMAIL_PATTERN = '[^@]+@[^@.]+\.[^@]+'

    attr_reader :form,
                :attribute,
                :label,
                :type,
                :field_class,
                :field_data,
                :error_message,
                :error_messages,
                :country_selector,
                :country_attribute,
                :selected_country,
                :allowed_countries,
                :confirmed_phone

    def initialize(
      form:,
      attribute:,
      label:,
      type: :text,
      placeholder: nil,
      floating_label: true,
      field_class: nil,
      field_data: {},
      error_message: nil,
      error_messages: {},
      country_selector: false,
      country_attribute: :international_code,
      selected_country: nil,
      allowed_countries: nil,
      confirmed_phone: true,
      password_toggle_label: nil,
      password_toggle_hide_label: nil,
      **input_options
    )
      @form = form
      @attribute = attribute
      @label = label
      @type = type
      @placeholder = placeholder
      @country_selector = country_selector && type == :tel
      @floating_label = floating_label
      @field_class = field_class
      @field_data = field_data
      @error_message = error_message
      @error_messages = error_messages.to_h.transform_keys(&:to_sym)
      @country_attribute = country_attribute
      @selected_country = selected_country
      @allowed_countries = allowed_countries
      @confirmed_phone = confirmed_phone
      @password_toggle_label = password_toggle_label
      @password_toggle_hide_label = password_toggle_hide_label
      @input_options = input_options
    end

    def password?
      type == :password
    end

    def validation_error_messages
      {
        valueMissing: value_missing_error_message,
        typeMismatch: type_mismatch_error_message,
        patternMismatch: pattern_mismatch_error_message,
        badInput: bad_input_error_message,
      }.merge(error_messages).compact
    end

    def field_classes
      classes = ['usa-input']
      classes << 'usa-input--phone' if country_selector
      classes << 'usa-input--password' if password?
      classes << field_class if field_class.present?
      classes.join(' ')
    end

    def label_classes
      ['usa-input__label', ('usa-input__label--visible' unless @floating_label)].compact.join(' ')
    end

    def input_classes
      classes = ['usa-input__control']
      classes << 'usa-input__control--phone' if country_selector
      classes << 'usa-input__control--password' if password?
      classes << 'usa-input__control--floating' if @floating_label
      classes.concat(Array(@input_options[:class]))
      classes.join(' ')
    end

    def error_id
      "#{form.object_name}_#{attribute}_nds_error"
    end

    def input_id
      @input_options[:id].presence || form.field_id(attribute)
    end

    def input_placeholder
      return ' ' if @floating_label

      @placeholder
    end

    def floating_label_text
      @placeholder.presence || label
    end

    def password_toggle_label
      @password_toggle_label || t('components.password_toggle.toggle_label')
    end

    def password_toggle_hide_label
      @password_toggle_hide_label || t('components.password_toggle.hide_label')
    end

    def country_options
      @country_options ||= begin
        codes = PhoneNumberCapabilities.translated_international_codes
        codes = codes.slice(*allowed_countries) if allowed_countries.present?
        codes
          .map do |code, data|
            dial_code = "+#{data['country_code']}"
            ["#{data['name']} (#{dial_code})", code, { data: country_option_data(data, dial_code) }]
          end
          .sort_by { |option_label, code| [code == 'US' ? 0 : 1, option_label] }
      end
    end

    def country_value
      object_country = if form.object&.respond_to?(country_attribute)
                         form.object.public_send(country_attribute)
                       end
      selected_country.presence || object_country.presence || 'US'
    end

    def country_dial_code
      country_options.find { |_label, code, _options| code == country_value }&.dig(
        2,
        :data,
        :dial_code,
      ) || '+1'
    end

    def render_input
      opts = @input_options.merge(
        aria: input_aria,
        class: input_classes,
        id: input_id,
        placeholder: input_placeholder,
      )
      opts[:autocomplete] ||= 'tel-national' if type == :tel
      opts[:inputmode] ||= 'tel' if type == :tel
      opts[:data] = (opts[:data] || {}).merge(nds_phone_input: true) if type == :tel

      case type
      when :date then form.date_field(attribute, **opts)
      when :email
        opts[:pattern] ||= EMAIL_PATTERN
        form.email_field(attribute, **opts)
      when :password then form.password_field(attribute, **opts)
      when :tel      then form.telephone_field(attribute, **opts)
      else                form.text_field(attribute, **opts)
      end
    end

    private

    def country_option_data(data, dial_code)
      supports_sms = data['supports_sms']
      supports_voice = data['supports_voice']
      supports_sms_unconfirmed = data.fetch('supports_sms_unconfirmed', supports_sms)
      supports_voice_unconfirmed = data.fetch('supports_voice_unconfirmed', supports_voice)

      {
        dial_code:,
        country_name: data['name'],
        supports_sms: supports_sms_unconfirmed || (confirmed_phone && supports_sms),
        supports_voice: supports_voice_unconfirmed || (confirmed_phone && supports_voice),
      }
    end

    def input_aria
      aria = @input_options.fetch(:aria, {}).to_h.transform_keys(&:to_sym)
      describedby = [aria[:describedby], error_id].compact.join(' ')
      invalid = aria.fetch(:invalid, error_message.present? || nil)
      aria.merge(describedby: describedby.presence, invalid: invalid).compact
    end

    def value_missing_error_message
      case type
      when :email then t('components.input.errors.email')
      when :password then t('components.input.errors.password')
      when :tel then t('components.input.errors.tel')
      when :date then t('components.input.errors.date')
      else t('components.input.errors.text')
      end
    end

    def type_mismatch_error_message
      case type
      when :email then t('components.input.errors.email')
      when :tel then t('components.input.errors.tel_invalid')
      when :date then t('components.input.errors.date_invalid')
      end
    end

    def pattern_mismatch_error_message
      case type
      when :email then t('components.input.errors.email')
      when :tel then t('components.input.errors.tel_invalid')
      when :password, :date then nil
      else t('components.input.errors.text_invalid')
      end
    end

    def bad_input_error_message
      case type
      when :date then t('components.input.errors.date_invalid')
      when :email then t('components.input.errors.email')
      when :tel then t('components.input.errors.tel_invalid')
      end
    end
  end
end
