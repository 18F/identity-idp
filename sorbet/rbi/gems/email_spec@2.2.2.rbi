# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `email_spec` gem.
# Please instead update this file by running `bin/tapioca gem email_spec`.


# source://email_spec//lib/email_spec/deliveries.rb#1
module EmailSpec; end

# source://email_spec//lib/email_spec/address_converter.rb#4
class EmailSpec::AddressConverter
  include ::Singleton
  extend ::Singleton::SingletonClassMethods

  # The block provided to conversion should convert to an email
  # address string or return the input untouched. For example:
  #
  #  EmailSpec::AddressConverter.instance.conversion do |input|
  #   if input.is_a?(User)
  #     input.email
  #   else
  #     input
  #   end
  #  end
  #
  # source://email_spec//lib/email_spec/address_converter.rb#20
  def conversion(&block); end

  # source://email_spec//lib/email_spec/address_converter.rb#24
  def convert(input); end

  # Returns the value of attribute converter.
  #
  # source://email_spec//lib/email_spec/address_converter.rb#7
  def converter; end

  # Sets the attribute converter
  #
  # @param value the value to set the attribute converter to.
  #
  # source://email_spec//lib/email_spec/address_converter.rb#7
  def converter=(_arg0); end

  class << self
    private

    def allocate; end
    def new(*_arg0); end
  end
end

# source://email_spec//lib/email_spec/errors.rb#2
class EmailSpec::CouldNotFindEmailError < ::StandardError; end

# source://email_spec//lib/email_spec/deliveries.rb#2
module EmailSpec::Deliveries
  # source://email_spec//lib/email_spec/deliveries.rb#3
  def all_emails; end

  # source://email_spec//lib/email_spec/deliveries.rb#7
  def last_email_sent; end

  # source://email_spec//lib/email_spec/deliveries.rb#21
  def mailbox_for(address); end

  # source://email_spec//lib/email_spec/deliveries.rb#11
  def reset_mailer; end

  protected

  # source://email_spec//lib/email_spec/deliveries.rb#27
  def deliveries; end

  # source://email_spec//lib/email_spec/deliveries.rb#39
  def mailer; end

  # source://email_spec//lib/email_spec/deliveries.rb#43
  def parse_ar_to_mail(email); end
end

# source://email_spec//lib/email_spec/email_viewer.rb#2
class EmailSpec::EmailViewer
  extend ::EmailSpec::Deliveries

  class << self
    # source://email_spec//lib/email_spec/email_viewer.rb#83
    def open_in_browser(filename); end

    # source://email_spec//lib/email_spec/email_viewer.rb#79
    def open_in_text_editor(filename); end

    # source://email_spec//lib/email_spec/email_viewer.rb#18
    def save_and_open_all_html_emails; end

    # source://email_spec//lib/email_spec/email_viewer.rb#5
    def save_and_open_all_raw_emails; end

    # source://email_spec//lib/email_spec/email_viewer.rb#30
    def save_and_open_all_text_emails; end

    # source://email_spec//lib/email_spec/email_viewer.rb#53
    def save_and_open_email(mail); end

    # source://email_spec//lib/email_spec/email_viewer.rb#63
    def save_and_open_email_attachments_list(mail); end

    # source://email_spec//lib/email_spec/email_viewer.rb#87
    def tmp_email_filename(extension = T.unsafe(nil)); end
  end
end

# source://email_spec//lib/email_spec/helpers.rb#6
module EmailSpec::Helpers
  include ::EmailSpec::Deliveries

  # source://email_spec//lib/email_spec/helpers.rb#21
  def click_email_link_matching(regex, email = T.unsafe(nil)); end

  # source://email_spec//lib/email_spec/helpers.rb#27
  def click_first_link_in_email(email = T.unsafe(nil)); end

  # @raise [exception_class]
  #
  # source://email_spec//lib/email_spec/helpers.rb#46
  def current_email(address = T.unsafe(nil)); end

  # source://email_spec//lib/email_spec/helpers.rb#58
  def current_email_attachments(address = T.unsafe(nil)); end

  # Should be able to accept String or Regexp options.
  #
  # source://email_spec//lib/email_spec/helpers.rb#72
  def find_email(address, opts = T.unsafe(nil)); end

  # source://email_spec//lib/email_spec/helpers.rb#87
  def links_in_email(email); end

  # source://email_spec//lib/email_spec/helpers.rb#32
  def open_email(address, opts = T.unsafe(nil)); end

  # source://email_spec//lib/email_spec/helpers.rb#32
  def open_email_for(address, opts = T.unsafe(nil)); end

  # source://email_spec//lib/email_spec/helpers.rb#38
  def open_last_email; end

  # source://email_spec//lib/email_spec/helpers.rb#42
  def open_last_email_for(address); end

  # source://email_spec//lib/email_spec/helpers.rb#67
  def read_emails_for(address); end

  # source://email_spec//lib/email_spec/helpers.rb#62
  def unread_emails_for(address); end

  # source://email_spec//lib/email_spec/helpers.rb#12
  def visit_in_email(link_text, address = T.unsafe(nil)); end

  private

  # source://email_spec//lib/email_spec/helpers.rb#173
  def convert_address(address); end

  # Overwrite this method to set default email address, for example:
  # last_email_address || @current_user.email
  #
  # source://email_spec//lib/email_spec/helpers.rb#180
  def current_email_address; end

  # source://email_spec//lib/email_spec/helpers.rb#189
  def email_spec_deprecate(text); end

  # source://email_spec//lib/email_spec/helpers.rb#94
  def email_spec_hash; end

  # source://email_spec//lib/email_spec/helpers.rb#98
  def find_email!(address, opts = T.unsafe(nil)); end

  # Returns the value of attribute last_email_address.
  #
  # source://email_spec//lib/email_spec/helpers.rb#171
  def last_email_address; end

  # source://email_spec//lib/email_spec/helpers.rb#185
  def mailbox_for(address); end

  # source://email_spec//lib/email_spec/helpers.rb#160
  def parse_email_count(amount); end

  # e.g. Click here in  <a href="http://confirm">Click here</a>
  #
  # source://email_spec//lib/email_spec/helpers.rb#147
  def parse_email_for_anchor_text_link(email, link_text); end

  # e.g. confirm in http://confirm
  #
  # source://email_spec//lib/email_spec/helpers.rb#140
  def parse_email_for_explicit_link(email, regex); end

  # source://email_spec//lib/email_spec/helpers.rb#118
  def parse_email_for_link(email, text_or_regex); end

  # source://email_spec//lib/email_spec/helpers.rb#133
  def request_uri(link); end

  # source://email_spec//lib/email_spec/helpers.rb#109
  def set_current_email(email); end

  # source://email_spec//lib/email_spec/helpers.rb#156
  def textify_images(email_body); end
end

# source://email_spec//lib/email_spec/helpers.rb#9
EmailSpec::Helpers::A_TAG_BEGIN_REGEX = T.let(T.unsafe(nil), Regexp)

# source://email_spec//lib/email_spec/helpers.rb#10
EmailSpec::Helpers::A_TAG_END_REGEX = T.let(T.unsafe(nil), Regexp)

# source://email_spec//lib/email_spec/mail_ext.rb#1
module EmailSpec::MailExt
  # source://email_spec//lib/email_spec/mail_ext.rb#2
  def default_part; end

  # source://email_spec//lib/email_spec/mail_ext.rb#6
  def default_part_body; end

  # source://email_spec//lib/email_spec/mail_ext.rb#11
  def html; end
end

# source://email_spec//lib/email_spec/matchers.rb#2
module EmailSpec::Matchers
  # source://email_spec//lib/email_spec/matchers.rb#145
  def bcc_to(*expected_email_addresses_or_objects_that_respond_to_email); end

  # source://email_spec//lib/email_spec/matchers.rb#109
  def be_delivered_from(email); end

  # source://email_spec//lib/email_spec/matchers.rb#75
  def be_delivered_to(*expected_email_addresses_or_objects_that_respond_to_email); end

  # source://email_spec//lib/email_spec/matchers.rb#179
  def cc_to(*expected_email_addresses_or_objects_that_respond_to_email); end

  # source://email_spec//lib/email_spec/matchers.rb#109
  def deliver_from(email); end

  # source://email_spec//lib/email_spec/matchers.rb#75
  def deliver_to(*expected_email_addresses_or_objects_that_respond_to_email); end

  # source://email_spec//lib/email_spec/matchers.rb#316
  def have_body_text(text); end

  # source://email_spec//lib/email_spec/matchers.rb#365
  def have_header(name, value); end

  # source://email_spec//lib/email_spec/matchers.rb#39
  def have_reply_to(email); end

  # source://email_spec//lib/email_spec/matchers.rb#224
  def have_subject(subject); end

  # source://email_spec//lib/email_spec/matchers.rb#269
  def include_email_with_subject(*emails); end

  # source://email_spec//lib/email_spec/matchers.rb#39
  def reply_to(email); end

  class << self
    # @private
    #
    # source://email_spec//lib/email_spec/matchers.rb#369
    def included(base); end
  end
end

# source://email_spec//lib/email_spec/matchers.rb#115
class EmailSpec::Matchers::BccTo < ::EmailSpec::Matchers::EmailMatcher
  # @return [BccTo] a new instance of BccTo
  #
  # source://email_spec//lib/email_spec/matchers.rb#117
  def initialize(expected_email_addresses_or_objects_that_respond_to_email); end

  # source://email_spec//lib/email_spec/matchers.rb#125
  def description; end

  # source://email_spec//lib/email_spec/matchers.rb#135
  def failure_message; end

  # source://email_spec//lib/email_spec/matchers.rb#139
  def failure_message_when_negated; end

  # @return [Boolean]
  #
  # source://email_spec//lib/email_spec/matchers.rb#129
  def matches?(email); end

  # source://email_spec//lib/email_spec/matchers.rb#139
  def negative_failure_message; end
end

# source://email_spec//lib/email_spec/matchers.rb#149
class EmailSpec::Matchers::CcTo < ::EmailSpec::Matchers::EmailMatcher
  # @return [CcTo] a new instance of CcTo
  #
  # source://email_spec//lib/email_spec/matchers.rb#151
  def initialize(expected_email_addresses_or_objects_that_respond_to_email); end

  # source://email_spec//lib/email_spec/matchers.rb#159
  def description; end

  # source://email_spec//lib/email_spec/matchers.rb#169
  def failure_message; end

  # source://email_spec//lib/email_spec/matchers.rb#173
  def failure_message_when_negated; end

  # @return [Boolean]
  #
  # source://email_spec//lib/email_spec/matchers.rb#163
  def matches?(email); end

  # source://email_spec//lib/email_spec/matchers.rb#173
  def negative_failure_message; end
end

# source://email_spec//lib/email_spec/matchers.rb#81
class EmailSpec::Matchers::DeliverFrom < ::EmailSpec::Matchers::EmailMatcher
  # @return [DeliverFrom] a new instance of DeliverFrom
  #
  # source://email_spec//lib/email_spec/matchers.rb#83
  def initialize(email); end

  # source://email_spec//lib/email_spec/matchers.rb#87
  def description; end

  # source://email_spec//lib/email_spec/matchers.rb#99
  def failure_message; end

  # source://email_spec//lib/email_spec/matchers.rb#103
  def failure_message_when_negated; end

  # @return [Boolean]
  #
  # source://email_spec//lib/email_spec/matchers.rb#91
  def matches?(email); end

  # source://email_spec//lib/email_spec/matchers.rb#103
  def negative_failure_message; end
end

# source://email_spec//lib/email_spec/matchers.rb#45
class EmailSpec::Matchers::DeliverTo < ::EmailSpec::Matchers::EmailMatcher
  # @return [DeliverTo] a new instance of DeliverTo
  #
  # source://email_spec//lib/email_spec/matchers.rb#46
  def initialize(expected_email_addresses_or_objects_that_respond_to_email); end

  # source://email_spec//lib/email_spec/matchers.rb#54
  def description; end

  # source://email_spec//lib/email_spec/matchers.rb#65
  def failure_message; end

  # source://email_spec//lib/email_spec/matchers.rb#69
  def failure_message_when_negated; end

  # @return [Boolean]
  #
  # source://email_spec//lib/email_spec/matchers.rb#58
  def matches?(email); end

  # source://email_spec//lib/email_spec/matchers.rb#69
  def negative_failure_message; end
end

# source://email_spec//lib/email_spec/matchers.rb#3
class EmailSpec::Matchers::EmailMatcher
  # source://email_spec//lib/email_spec/matchers.rb#4
  def address_array; end
end

# source://email_spec//lib/email_spec/matchers.rb#273
class EmailSpec::Matchers::HaveBodyText
  # @return [HaveBodyText] a new instance of HaveBodyText
  #
  # source://email_spec//lib/email_spec/matchers.rb#275
  def initialize(text); end

  # source://email_spec//lib/email_spec/matchers.rb#279
  def description; end

  # source://email_spec//lib/email_spec/matchers.rb#298
  def failure_message; end

  # source://email_spec//lib/email_spec/matchers.rb#306
  def failure_message_when_negated; end

  # @return [Boolean]
  #
  # source://email_spec//lib/email_spec/matchers.rb#287
  def matches?(email); end

  # source://email_spec//lib/email_spec/matchers.rb#306
  def negative_failure_message; end
end

# source://email_spec//lib/email_spec/matchers.rb#320
class EmailSpec::Matchers::HaveHeader
  # @return [HaveHeader] a new instance of HaveHeader
  #
  # source://email_spec//lib/email_spec/matchers.rb#322
  def initialize(name, value); end

  # source://email_spec//lib/email_spec/matchers.rb#326
  def description; end

  # source://email_spec//lib/email_spec/matchers.rb#343
  def failure_message; end

  # source://email_spec//lib/email_spec/matchers.rb#351
  def failure_message_when_negated; end

  # source://email_spec//lib/email_spec/matchers.rb#360
  def mail_headers_hash(email_headers); end

  # @return [Boolean]
  #
  # source://email_spec//lib/email_spec/matchers.rb#334
  def matches?(email); end

  # source://email_spec//lib/email_spec/matchers.rb#351
  def negative_failure_message; end
end

# source://email_spec//lib/email_spec/matchers.rb#183
class EmailSpec::Matchers::HaveSubject
  # @return [HaveSubject] a new instance of HaveSubject
  #
  # source://email_spec//lib/email_spec/matchers.rb#185
  def initialize(subject); end

  # source://email_spec//lib/email_spec/matchers.rb#189
  def description; end

  # source://email_spec//lib/email_spec/matchers.rb#206
  def failure_message; end

  # source://email_spec//lib/email_spec/matchers.rb#214
  def failure_message_when_negated; end

  # @return [Boolean]
  #
  # source://email_spec//lib/email_spec/matchers.rb#197
  def matches?(email); end

  # source://email_spec//lib/email_spec/matchers.rb#214
  def negative_failure_message; end
end

# source://email_spec//lib/email_spec/matchers.rb#228
class EmailSpec::Matchers::IncludeEmailWithSubject
  # @return [IncludeEmailWithSubject] a new instance of IncludeEmailWithSubject
  #
  # source://email_spec//lib/email_spec/matchers.rb#230
  def initialize(subject); end

  # source://email_spec//lib/email_spec/matchers.rb#234
  def description; end

  # source://email_spec//lib/email_spec/matchers.rb#251
  def failure_message; end

  # source://email_spec//lib/email_spec/matchers.rb#259
  def failure_message_when_negated; end

  # @return [Boolean]
  #
  # source://email_spec//lib/email_spec/matchers.rb#242
  def matches?(emails); end

  # source://email_spec//lib/email_spec/matchers.rb#259
  def negative_failure_message; end
end

# source://email_spec//lib/email_spec/matchers.rb#13
class EmailSpec::Matchers::ReplyTo
  # @return [ReplyTo] a new instance of ReplyTo
  #
  # source://email_spec//lib/email_spec/matchers.rb#14
  def initialize(email); end

  # source://email_spec//lib/email_spec/matchers.rb#18
  def description; end

  # source://email_spec//lib/email_spec/matchers.rb#29
  def failure_message; end

  # source://email_spec//lib/email_spec/matchers.rb#33
  def failure_message_when_negated; end

  # @return [Boolean]
  #
  # source://email_spec//lib/email_spec/matchers.rb#22
  def matches?(email); end

  # source://email_spec//lib/email_spec/matchers.rb#33
  def negative_failure_message; end
end

# source://email_spec//lib/email_spec/errors.rb#5
class EmailSpec::NoEmailAddressProvided < ::StandardError; end

# source://email_spec//lib/email_spec/test_observer.rb#2
class EmailSpec::TestObserver
  class << self
    # source://email_spec//lib/email_spec/test_observer.rb#3
    def delivered_email(message); end
  end
end

class Mail::Message
  include ::EmailSpec::MailExt
end