# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `safe_target_blank` gem.
# Please instead update this file by running `bin/tapioca gem safe_target_blank`.


# source://safe_target_blank//lib/safe_target_blank/url_helper.rb#1
module ActionView
  class << self
    # source://actionview/7.2.1.1/lib/action_view/deprecator.rb#4
    def deprecator; end

    # source://actionview/7.2.1.1/lib/action_view.rb#93
    def eager_load!; end

    # source://actionview/7.2.1.1/lib/action_view/gem_version.rb#5
    def gem_version; end

    # source://actionview/7.2.1.1/lib/action_view/version.rb#7
    def version; end
  end
end

# source://safe_target_blank//lib/safe_target_blank/url_helper.rb#2
module ActionView::Helpers
  include ::ActionView::Helpers::SanitizeHelper
  include ::DOTIW::Methods
  include ::ActionView::Helpers::TextHelper
  include ::ActionView::Helpers::UrlHelper
  include ::ActionView::Helpers::SanitizeHelper
  include ::ActionView::Helpers::TextHelper
  include ::ActionView::Helpers::FormTagHelper
  include ::ActionView::Helpers::FormHelper
  include ::ActionView::Helpers::TranslationHelper

  mixes_in_class_methods ::ActionView::Helpers::UrlHelper::ClassMethods
  mixes_in_class_methods ::ActionView::Helpers::SanitizeHelper::ClassMethods

  class << self
    # source://actionview/7.2.1.1/lib/action_view/helpers.rb#35
    def eager_load!; end
  end
end

# source://safe_target_blank//lib/safe_target_blank/url_helper.rb#3
module ActionView::Helpers::UrlHelper
  include ::ActionView::Helpers::CaptureHelper
  include ::ActionView::Helpers::OutputSafetyHelper

  mixes_in_class_methods ::ActionView::Helpers::UrlHelper::ClassMethods

  # source://actionview/7.2.1.1/lib/action_view/helpers/url_helper.rb#296
  def button_to(name = T.unsafe(nil), options = T.unsafe(nil), html_options = T.unsafe(nil), &block); end

  # source://actionview/7.2.1.1/lib/action_view/helpers/url_helper.rb#35
  def button_to_generates_button_tag; end

  # source://actionview/7.2.1.1/lib/action_view/helpers/url_helper.rb#35
  def button_to_generates_button_tag=(val); end

  # source://safe_target_blank//lib/safe_target_blank/url_helper.rb#25
  def convert_options_to_data_attributes(options, html_options); end

  # source://actionview/7.2.1.1/lib/action_view/helpers/url_helper.rb#548
  def current_page?(options = T.unsafe(nil), check_parameters: T.unsafe(nil), **options_as_kwargs); end

  # source://actionview/7.2.1.1/lib/action_view/helpers/url_helper.rb#198
  def link_to(name = T.unsafe(nil), options = T.unsafe(nil), html_options = T.unsafe(nil), &block); end

  # source://actionview/7.2.1.1/lib/action_view/helpers/url_helper.rb#437
  def link_to_if(condition, name, options = T.unsafe(nil), html_options = T.unsafe(nil), &block); end

  # @return [Boolean]
  #
  # source://safe_target_blank//lib/safe_target_blank/url_helper.rb#14
  def link_to_option_enabled?(html_options, option); end

  # source://safe_target_blank//lib/safe_target_blank/url_helper.rb#10
  def link_to_rel_from_html_options(html_options); end

  # @return [Boolean]
  #
  # source://safe_target_blank//lib/safe_target_blank/url_helper.rb#6
  def link_to_target_blank?(html_options); end

  # source://safe_target_blank//lib/safe_target_blank/url_helper.rb#18
  def link_to_target_blank_default_rel(html_options); end

  # source://actionview/7.2.1.1/lib/action_view/helpers/url_helper.rb#414
  def link_to_unless(condition, name, options = T.unsafe(nil), html_options = T.unsafe(nil), &block); end

  # source://actionview/7.2.1.1/lib/action_view/helpers/url_helper.rb#390
  def link_to_unless_current(name, options = T.unsafe(nil), html_options = T.unsafe(nil), &block); end

  # source://actionview/7.2.1.1/lib/action_view/helpers/url_helper.rb#487
  def mail_to(email_address, name = T.unsafe(nil), html_options = T.unsafe(nil), &block); end

  # source://actionview/7.2.1.1/lib/action_view/helpers/url_helper.rb#669
  def phone_to(phone_number, name = T.unsafe(nil), html_options = T.unsafe(nil), &block); end

  # source://actionview/7.2.1.1/lib/action_view/helpers/url_helper.rb#618
  def sms_to(phone_number, name = T.unsafe(nil), html_options = T.unsafe(nil), &block); end

  # source://actionview/7.2.1.1/lib/action_view/helpers/url_helper.rb#38
  def url_for(options = T.unsafe(nil)); end

  private

  # source://actionview/7.2.1.1/lib/action_view/helpers/url_helper.rb#50
  def _back_url; end

  # source://actionview/7.2.1.1/lib/action_view/helpers/url_helper.rb#55
  def _filtered_referrer; end

  # source://actionview/7.2.1.1/lib/action_view/helpers/url_helper.rb#712
  def add_method_to_attributes!(html_options, method); end

  # source://actionview/7.2.1.1/lib/action_view/helpers/url_helper.rb#706
  def link_to_remote_options?(options); end

  # source://actionview/7.2.1.1/lib/action_view/helpers/url_helper.rb#723
  def method_for_options(options); end

  # source://actionview/7.2.1.1/lib/action_view/helpers/url_helper.rb#741
  def method_not_get_method?(method); end

  # source://actionview/7.2.1.1/lib/action_view/helpers/url_helper.rb#760
  def method_tag(method); end

  # source://actionview/7.2.1.1/lib/action_view/helpers/url_helper.rb#683
  def original_convert_options_to_data_attributes(options, html_options); end

  # source://actionview/7.2.1.1/lib/action_view/helpers/url_helper.rb#806
  def remove_trailing_slash!(url_string); end

  # source://actionview/7.2.1.1/lib/action_view/helpers/url_helper.rb#780
  def to_form_params(attribute, namespace = T.unsafe(nil)); end

  # source://actionview/7.2.1.1/lib/action_view/helpers/url_helper.rb#746
  def token_tag(token = T.unsafe(nil), form_options: T.unsafe(nil)); end

  # source://actionview/7.2.1.1/lib/action_view/helpers/url_helper.rb#698
  def url_target(name, options); end

  class << self
    # source://actionview/7.2.1.1/lib/action_view/helpers/url_helper.rb#35
    def button_to_generates_button_tag; end

    # source://actionview/7.2.1.1/lib/action_view/helpers/url_helper.rb#35
    def button_to_generates_button_tag=(val); end
  end
end

# source://safe_target_blank//lib/safe_target_blank/version.rb#1
module SafeTargetBlank
  class << self
    # source://safe_target_blank//lib/safe_target_blank.rb#7
    def opener; end

    # source://safe_target_blank//lib/safe_target_blank.rb#11
    def opener=(opener); end

    # source://safe_target_blank//lib/safe_target_blank.rb#15
    def referrer; end

    # source://safe_target_blank//lib/safe_target_blank.rb#19
    def referrer=(referrer); end
  end
end

# source://safe_target_blank//lib/safe_target_blank/version.rb#2
SafeTargetBlank::VERSION = T.let(T.unsafe(nil), String)