# frozen_string_literal: true

require 'rails_helper'
require 'i18n/tasks'

# List of keys allowed to contain different interpolation arguments across locales
ALLOWED_INTERPOLATION_MISMATCH_KEYS = [
  'time.formats.event_timestamp_js',
].sort.freeze

ALLOWED_LEADING_OR_TRAILING_SPACE_KEYS = [
  'datetime.dotiw.last_word_connector',
  'datetime.dotiw.two_words_connector',
  'datetime.dotiw.words_connector',
].sort.freeze

# These are keys with mismatch interpolation for specific locales
ALLOWED_INTERPOLATION_MISMATCH_LOCALE_KEYS = [
  # need to be fixed
  'zh.account_reset.pending.confirm',
  'zh.account_reset.pending.wait_html',
  'zh.account_reset.recovery_options.check_webauthn_platform_info',
  'zh.doc_auth.headings.welcome',
  'zh.doc_auth.info.exit.with_sp',
  'zh.idv.cancel.headings.exit.with_sp',
  'zh.idv.failure.exit.with_sp',
  'zh.in_person_proofing.body.barcode.return_to_partner_link',
  'zh.telephony.account_reset_notice',
  'zh.two_factor_authentication.account_reset.pending',
  'zh.user_mailer.account_reset_granted.intro_html',
  'zh.user_mailer.account_reset_request.header',
  'zh.user_mailer.account_reset_request.intro_html',
  'zh.user_mailer.in_person_verified.next_sign_in.without_sp',
  'zh.user_mailer.in_person_verified.subject',
  'zh.user_mailer.new_device_sign_in.info',
].sort.freeze

# A set of patterns which are expected to only occur within specific locales. This is an imperfect
# solution based on current content, intended to help prevent accidents when adding new translated
# content. If you are having issues with new content, it would be reasonable to remove or modify
# the parts of the pattern which are valid for the content you're adding.
LOCALE_SPECIFIC_CONTENT = {
  fr: / [nd]’|à/i,
  es: /¿|ó/,
}.freeze

# Regex patterns for commonly misspelled words by locale. Match on word boundaries ignoring case.
# The current design should be adequate for a small number of words in each language.
# If we encounter false positives we should come up with a scheme to ignore those cases.
# Add additional words using the regex union operator '|'.
COMMONLY_MISSPELLED_WORDS = {
  en: /\b(cancelled|occured|seperated?)\b/i,
}.freeze

module I18n
  module Tasks
    class BaseTask
      # List of keys allowed to be untranslated or are the same as English
      # rubocop:disable Layout/LineLength
      ALLOWED_UNTRANSLATED_KEYS = [
        { key: 'account.navigation.menu', locales: %i[fr] }, # "Menu" is "Menu" in French
        { key: /^countries/ }, # Some countries have the same name across languages
        { key: 'datetime.dotiw.minutes.one' }, # "minute is minute" in French and English
        { key: 'datetime.dotiw.minutes.other' }, # "minute is minute" in French and English
        { key: 'time.formats.full_date', locales: %i[es] }, # format is the same in Spanish and English
        { key: 'i18n.locale.en', locales: %i[es fr zh] },
        { key: 'i18n.locale.es', locales: %i[es fr zh] },
        { key: 'i18n.locale.fr', locales: %i[es fr zh] },
        { key: 'i18n.locale.zh', locales: %i[es fr zh] },
        { key: 'links.contact', locales: %i[fr] }, # "Contact" is "Contact" in French
        { key: 'saml_idp.auth.error.title', locales: %i[es] }, # "Error" is "Error" in Spanish
        { key: 'simple_form.no', locales: %i[es] }, # "No" is "No" in Spanish
        { key: 'time.formats.sms_date' }, # for us date format
        { key: 'datetime.dotiw.words_connector' }, # " , " is only punctuation and not translated
        { key: 'date.formats.long', locales: %i[es zh] },
        { key: 'date.formats.short', locales: %i[es zh] },
        { key: 'time.formats.event_date', locales: %i[es zh] },
        { key: 'time.formats.event_time', locales: %i[es zh] },
        { key: 'time.formats.event_timestamp', locales: %i[zh] },
        # need to be fixed
        { key: 'account.email_language.name.zh', locales: %i[es fr] },
        { key: 'account_reset.pending.canceled', locales: %i[zh] },
        { key: 'account_reset.recovery_options.check_saved_credential', locales: %i[zh] },
        { key: 'account_reset.recovery_options.use_same_device', locales: %i[zh] },
        { key: 'anonymous_mailer.password_reset_missing_user.create_new_account', locales: %i[zh] },
        { key: 'anonymous_mailer.password_reset_missing_user.info_no_account', locales: %i[zh] },
        { key: 'anonymous_mailer.password_reset_missing_user.info_request_different', locales: %i[zh] },
        { key: 'anonymous_mailer.password_reset_missing_user.subject', locales: %i[zh] },
        { key: 'anonymous_mailer.password_reset_missing_user.try_different_email', locales: %i[zh] },
        { key: 'anonymous_mailer.password_reset_missing_user.use_this_email_html', locales: %i[zh] },
        { key: 'doc_auth.buttons.close', locales: %i[zh] },
        { key: 'doc_auth.info.getting_started_html', locales: %i[zh] },
        { key: 'doc_auth.info.getting_started_learn_more', locales: %i[zh] },
        { key: 'doc_auth.info.stepping_up_html', locales: %i[zh] },
        { key: 'doc_auth.instructions.bullet4', locales: %i[zh] },
        { key: 'doc_auth.instructions.getting_started', locales: %i[zh] },
        { key: 'doc_auth.instructions.text3', locales: %i[zh] },
        { key: 'doc_auth.instructions.text4', locales: %i[zh] },
        { key: 'errors.doc_auth.document_capture_canceled', locales: %i[zh] },
        { key: 'errors.messages.blank_cert_element_req', locales: %i[zh] },
        { key: 'forms.webauthn_setup.learn_more', locales: %i[zh] },
        { key: 'forms.webauthn_setup.step_1', locales: %i[zh] },
        { key: 'forms.webauthn_setup.step_1a', locales: %i[zh] },
        { key: 'forms.webauthn_setup.step_2_image_alt', locales: %i[zh] },
        { key: 'forms.webauthn_setup.step_2_image_mobile_alt', locales: %i[zh] },
        { key: 'idv.failure.setup.fail_html', locales: %i[zh] },
        { key: 'idv.failure.verify.exit', locales: %i[zh] },
        { key: 'in_person_proofing.form.state_id.state_id_number_florida_hint_html', locales: %i[zh] },
        { key: 'mfa.recommendation', locales: %i[zh] },
        { key: 'notices.signed_up_but_unconfirmed.resend_confirmation_email', locales: %i[zh] },
        { key: 'openid_connect.authorization.errors.no_valid_vtr', locales: %i[zh] },
        { key: 'telephony.account_deleted_notice', locales: %i[zh] },
        { key: 'telephony.format_length.six', locales: %i[zh] },
        { key: 'telephony.format_length.ten', locales: %i[zh] },
        { key: 'titles.idv.canceled', locales: %i[zh] },
        { key: 'titles.piv_cac_setup.upsell', locales: %i[zh] },
        { key: 'two_factor_authentication.auth_app.change_nickname', locales: %i[zh] },
        { key: 'two_factor_authentication.auth_app.delete', locales: %i[zh] },
        { key: 'two_factor_authentication.auth_app.deleted', locales: %i[zh] },
        { key: 'two_factor_authentication.auth_app.edit_heading', locales: %i[zh] },
        { key: 'two_factor_authentication.auth_app.manage_accessible_label', locales: %i[zh] },
        { key: 'two_factor_authentication.auth_app.nickname', locales: %i[zh] },
        { key: 'two_factor_authentication.auth_app.renamed', locales: %i[zh] },
        { key: 'two_factor_authentication.piv_cac.change_nickname', locales: %i[zh] },
        { key: 'two_factor_authentication.piv_cac.delete', locales: %i[zh] },
        { key: 'two_factor_authentication.piv_cac.deleted', locales: %i[zh] },
        { key: 'two_factor_authentication.piv_cac.edit_heading', locales: %i[zh] },
        { key: 'two_factor_authentication.piv_cac.manage_accessible_label', locales: %i[zh] },
        { key: 'two_factor_authentication.piv_cac.nickname', locales: %i[zh] },
        { key: 'two_factor_authentication.piv_cac.renamed', locales: %i[zh] },
        { key: 'two_factor_authentication.piv_cac_upsell.add_piv', locales: %i[zh] },
        { key: 'two_factor_authentication.piv_cac_upsell.choose_other_method', locales: %i[zh] },
        { key: 'two_factor_authentication.piv_cac_upsell.existing_user_info', locales: %i[zh] },
        { key: 'two_factor_authentication.piv_cac_upsell.new_user_info', locales: %i[zh] },
        { key: 'two_factor_authentication.piv_cac_upsell.skip', locales: %i[zh] },
        { key: 'two_factor_authentication.recommended', locales: %i[zh] },
        { key: 'two_factor_authentication.webauthn_roaming.change_nickname', locales: %i[zh] },
        { key: 'two_factor_authentication.webauthn_roaming.delete', locales: %i[zh] },
        { key: 'two_factor_authentication.webauthn_roaming.deleted', locales: %i[zh] },
        { key: 'two_factor_authentication.webauthn_roaming.edit_heading', locales: %i[zh] },
        { key: 'two_factor_authentication.webauthn_roaming.manage_accessible_label', locales: %i[zh] },
        { key: 'two_factor_authentication.webauthn_roaming.nickname', locales: %i[zh] },
        { key: 'two_factor_authentication.webauthn_roaming.renamed', locales: %i[zh] },
        { key: 'user_mailer.new_device_sign_in_after_2fa.authentication_methods', locales: %i[zh] },
        { key: 'user_mailer.new_device_sign_in_after_2fa.info_p3_html', locales: %i[zh] },
        { key: 'user_mailer.new_device_sign_in_after_2fa.reset_password', locales: %i[zh] },
        { key: 'user_mailer.new_device_sign_in_attempts.events.sign_in_before_2fa', locales: %i[zh] },
        { key: 'user_mailer.new_device_sign_in_before_2fa.info_p1_html.one', locales: %i[zh] },
        { key: 'user_mailer.new_device_sign_in_before_2fa.info_p1_html.other', locales: %i[zh] },
        { key: 'user_mailer.new_device_sign_in_before_2fa.info_p1_html.zero', locales: %i[zh] },
      ].freeze
      # rubocop:enable Layout/LineLength

      def leading_or_trailing_whitespace_keys
        self.locales.each_with_object([]) do |locale, result|
          data[locale].key_values.each_with_object(result) do |key_value, result|
            key, value = key_value
            next if ALLOWED_LEADING_OR_TRAILING_SPACE_KEYS.include?(key)

            leading_or_trailing_whitespace =
              if value.is_a?(String)
                leading_or_trailing_whitespace?(value)
              elsif value.is_a?(Array)
                value.compact.any? { |x| leading_or_trailing_whitespace?(x) }
              end

            if leading_or_trailing_whitespace
              result << "#{locale}.#{key}"
            end

            result
          end
        end
      end

      def leading_or_trailing_whitespace?(value)
        value.match?(/\A\s|\s\z/)
      end

      def untranslated_keys
        data[base_locale].key_values.each_with_object([]) do |key_value, result|
          key, value = key_value

          result << key if untranslated_key?(key, value)
          result
        end
      end

      def untranslated_key?(key, base_locale_value)
        locales = self.locales - [base_locale]
        locales.any? do |current_locale|
          node = data[current_locale].first.children[key]
          next unless node&.value&.is_a?(String)
          next if node.value.empty?
          next unless node.value == base_locale_value
          true unless allowed_untranslated_key?(current_locale, key)
        end
      end

      def allowed_untranslated_key?(locale, key)
        ALLOWED_UNTRANSLATED_KEYS.any? do |entry|
          next if entry[:key].is_a?(Regexp) && !key.match?(entry[:key])
          next if entry[:key].is_a?(String) && key != entry[:key]

          if !entry.key?(:locales) || entry[:locales].include?(locale.to_sym)
            entry[:used] = true

            true
          end
        end
      end
    end
  end
end

RSpec.describe 'I18n' do
  let(:i18n) { I18n::Tasks::BaseTask.new }
  let(:missing_keys) { i18n.missing_keys }
  let(:unused_keys) { i18n.unused_keys }
  let(:untranslated_keys) { i18n.untranslated_keys }
  let(:leading_or_trailing_whitespace_keys) do
    i18n.leading_or_trailing_whitespace_keys
  end

  it 'does not have missing keys' do
    expect(missing_keys).to(
      be_empty,
      "Missing #{missing_keys.leaves.count} i18n keys, run `i18n-tasks missing' to show them",
    )
  end

  it 'does not have leading or trailing whitespace' do
    expect(leading_or_trailing_whitespace_keys).to(
      be_empty,
      "keys with leading or trailing whitespace: #{leading_or_trailing_whitespace_keys}",
    )
  end

  it 'does not have unused keys' do
    expect(unused_keys).to(
      be_empty,
      "#{unused_keys.leaves.count} unused i18n keys, run `i18n-tasks unused' to show them",
    )
  end

  it 'does not have untranslated keys' do
    expect(untranslated_keys).to(
      be_empty,
      "untranslated i18n keys: #{untranslated_keys}",
    )

    unused_allowed_untranslated_keys =
      I18n::Tasks::BaseTask::ALLOWED_UNTRANSLATED_KEYS.reject { |key| key[:used] }
    expect(unused_allowed_untranslated_keys).to(
      be_empty,
      <<~EOS,
        ALLOWED_UNTRANSLATED_KEYS contains unused allowed untranslated i18n keys.
        The following keys can be removed from ALLOWED_UNTRANSLATED_KEYS:
        #{unused_allowed_untranslated_keys.pretty_inspect}
      EOS
    )
  end

  it 'does not have keys with missing interpolation arguments (check callsites for correct args)' do
    missing_interpolation_argument_keys = []
    missing_interpolation_argument_locale_keys = []

    i18n.data[i18n.base_locale].select_keys do |key, _node|
      if key.start_with?('i18n.transliterate.rule.') || i18n.t(key).is_a?(Array) || i18n.t(key).nil?
        next
      end

      interpolation_arguments = i18n.locales.map do |locale|
        if ALLOWED_INTERPOLATION_MISMATCH_LOCALE_KEYS.include?("#{locale}.#{key}")
          missing_interpolation_argument_locale_keys.push("#{locale}.#{key}")
          next
        end
        extract_interpolation_arguments i18n.t(key, locale)
      end.compact

      missing_interpolation_argument_keys.push(key) if interpolation_arguments.uniq.length > 1
    end

    expect(missing_interpolation_argument_keys.sort).to eq ALLOWED_INTERPOLATION_MISMATCH_KEYS
    expect(missing_interpolation_argument_locale_keys.sort).to eq(
      ALLOWED_INTERPOLATION_MISMATCH_LOCALE_KEYS,
    )
  end

  it 'has matching HTML tags' do
    i18n.data[i18n.base_locale].select_keys do |key, _node|
      if key.start_with?('i18n.transliterate.rule.') || i18n.t(key).is_a?(Array) || i18n.t(key).nil?
        next
      end

      html_unique_tags = i18n.locales.map { |locale| i18n.t(key, locale)&.scan(/<.+?>/) }.uniq

      expect(html_unique_tags.size).to eq(1), "HTML tag mismatch for key #{key}"
    end
  end

  root_dir = File.expand_path(File.join(File.dirname(__FILE__), '../'))

  ([File.join(root_dir, '/config/locales')] + Dir[File.join(root_dir, '/config/locales/**')]).
    sort.each do |group_path|
    i18n_group = group_path.sub("#{root_dir}/", '')

    describe i18n_group do
      it 'has HTML inside at least one locale string for all keys with .html or _html ' do
        combined = Hash.new { |h, k| h[k] = {} }

        Dir["#{group_path}/**.yml"].each do |file|
          locale = I18nFlatYmlBackend.locale(file)
          data = YAML.load_file(file)
          flatten_hash(data, flatten_arrays: false).each do |key, str|
            combined[key][locale] = str
          end
        end

        bad_keys = combined.select do |key, locales|
          next if locales.values.all?(&:blank?)

          key.include?('html') ^ contains_html?(locales.values)
        end

        expect(bad_keys).to be_empty
      end
    end
  end

  Dir[File.join(root_dir, '/config/locales/**/*.yml')].sort.each do |full_path|
    i18n_file = full_path.sub("#{root_dir}/", '')
    locale = File.basename(full_path, '.yml').to_sym

    describe i18n_file do
      let(:flattened_yaml_data) { flatten_hash(YAML.load_file(full_path)) }

      # Transliteration includes special characters by definition, so it could fail checks below
      if !full_path.match?(%(/config/locales/transliterate/))
        it 'has only lower_snake_case keys' do
          keys = flattened_yaml_data.keys

          bad_keys = keys.reject { |key| key =~ /^[a-z0-9_.]+$/ }
          expect(bad_keys).to be_empty
        end
      end

      it 'has correctly-formatted interpolation values' do
        bad_keys = flattened_yaml_data.select do |_key, value|
          next unless value.is_a?(String)

          interpolation_names = value.scan(/%\{([^}]+)\}/).flatten

          interpolation_names.any? { |name| name.downcase != name }
        end

        expect(bad_keys).to be_empty
      end

      it 'does not contain any translations expecting legacy fallback behavior' do
        bad_keys = flattened_yaml_data.select do |_key, value|
          value.include?('NOT TRANSLATED YET')
        end

        expect(bad_keys).to be_empty
      end

      it 'does not contain any translations that hardcode APP_NAME' do
        bad_keys = flattened_yaml_data.select do |_key, value|
          value.include?(APP_NAME)
        end

        expect(bad_keys).to be_empty
      end

      it 'does not contain content from another language' do
        flattened_yaml_data.each do |key, value|
          other_locales = LOCALE_SPECIFIC_CONTENT.keys - [locale]
          expect(value).not_to match(
            Regexp.union(*LOCALE_SPECIFIC_CONTENT.slice(*other_locales).values),
          )
        end
      end

      it 'does not contain common misspellings', if: COMMONLY_MISSPELLED_WORDS.key?(locale) do
        flattened_yaml_data.each do |key, value|
          expect(value).not_to match(COMMONLY_MISSPELLED_WORDS[locale])
        end
      end
    end
  end

  def contains_html?(value)
    Array(value).flatten.compact.any? do |str|
      html_tags?(str) || html_entities?(str) || likely_html_interpolation?(str)
    end
  end

  def html_tags?(str)
    str.scan(/<.+?>/).present?
  end

  def html_entities?(str)
    str.scan(/&[^;]+?;/).present?
  end

  def likely_html_interpolation?(str)
    str.scan(I18n::INTERPOLATION_PATTERN).flatten.compact.any? do |key|
      key.include?('html')
    end
  end

  def extract_interpolation_arguments(translation)
    translation.scan(I18n::INTERPOLATION_PATTERN).
      map(&:compact).map(&:first).to_set
  end

  def flatten_hash(hash, flatten_arrays: true, parent_keys: [], out_hash: {})
    hash.each do |key, value|
      if value.is_a?(Hash)
        flatten_hash(value, flatten_arrays:, parent_keys: parent_keys + [key], out_hash:)
      elsif value.is_a?(Array) && flatten_arrays
        value.each_with_index do |item, idx|
          flat_key = [*parent_keys, key, idx.to_s].join('.')
          out_hash[flat_key] = item if item
        end
      else
        flat_key = [*parent_keys, key].join('.')
        out_hash[flat_key] = value if value
      end
    end

    out_hash
  end
end
