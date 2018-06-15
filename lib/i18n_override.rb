require 'i18n'

I18n.module_eval do
  class << self
    def translate_with_markup(*args)
      i18n_text = normal_translate(*args)
      return i18n_text unless FeatureManagement.enable_i18n_mode? && i18n_text.is_a?(String)
      return i18n_text if caller(2..2).first.match?(/flows_spec.rb|session_helper.rb/)

      key = args.first.to_s
      rtn = i18n_text + i18n_mode_additional_markup(key)

      rtn.html_safe
    end

    private

    def i18n_mode_additional_markup(key)
      traverser = I18nLocaleTraverser.new(key, normal_translate(key))
      uri = traverser.locale_uri

      return '' unless uri

      "<small class=\"i18n-anchor\"><a href=\"#{uri}\" " \
      "target=\"_blank\" class=\"ml-tiny no-hover-decoration\">🔗</a></small>"
    end

    alias_method :normal_translate, :translate
    alias_method :translate, :translate_with_markup
  end
end

class I18nLocaleTraverser
  def initialize(key, localized_str)
    @key = key
    @localized_str = localized_str
    @file = find_file_by_key
  end

  def locale_uri
    return nil unless @file
    base_uri = 'https://github.com/18F/identity-idp/blob/master/config/locales/'
    base_uri + filename + '#L' + find_line_number.to_s
  end

  private

  attr_reader :match_str

  def find_file_by_key
    i18n_files.each do |file|
      location = traverse_file_for_key(file)
      return location if location
    end
    nil
  end

  def filename
    @file.split('/').last(2).join('/')
  end

  def find_line_number
    match_line_in_file(@file, line_regex)
  end

  def match_line_in_file(file, match_arr)
    File.foreach(file).with_index do |line, index|
      break index + 1 if line.match?(/#{match_arr.join('|')}/)
    end
  end

  def i18n_files
    Dir[Rails.root.join('config', 'locales', '**', '*.{yml}').to_s]
  end

  def traverse_file_for_key(file)
    yml = YAML.safe_load(File.open(file))[I18n.config.locale.to_s]

    elements = @key.split('.')

    return file if find_multilevel_hash_value(yml, elements)
  end

  def find_multilevel_hash_value(hsh, keys)
    keys.inject(hsh) { |sub, elm| sub[elm] if sub.is_a?(Hash) }
  end

  def line_regex
    key_arr = @key.split('.')
    spaces = 2 * key_arr.length
    last_key = key_arr.last

    @match_str = ' ' * spaces + last_key + ':'

    line_match_regex_arr
  end

  def line_match_regex_arr
    [match_with_value,
     match_with_single_quotes,
     match_with_double_quotes,
     match_with_multiline]
  end

  def match_with_value
    match_str + ' ' + @localized_str
  end

  def match_with_single_quotes
    match_str + ' \'' + @localized_str
  end

  def match_with_double_quotes
    match_str + ' "' + @localized_str
  end

  def match_with_multiline
    match_str + ' >' # assuming localized_str is on next line
  end
end
