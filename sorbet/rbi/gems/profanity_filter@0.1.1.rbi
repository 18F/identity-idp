# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `profanity_filter` gem.
# Please instead update this file by running `bin/tapioca gem profanity_filter`.


class ActiveRecord::Base
  include ::ActiveModel::ForbiddenAttributesProtection
  include ::ActiveModel::AttributeAssignment
  include ::ActiveModel::Access
  include ::ActiveModel::Serialization
  include ::ProfanityFilter
  extend ::ProfanityFilter::ClassMethods
end

# source://profanity_filter//lib/profanity_filter.rb#1
module ProfanityFilter
  mixes_in_class_methods ::ProfanityFilter::ClassMethods

  class << self
    # @private
    #
    # source://profanity_filter//lib/profanity_filter.rb#2
    def included(base); end
  end
end

# source://profanity_filter//lib/profanity_filter.rb#35
class ProfanityFilter::Base
  # source://profanity_filter//lib/profanity_filter.rb#36
  def dictionary; end

  # source://profanity_filter//lib/profanity_filter.rb#36
  def dictionary=(val); end

  # source://profanity_filter//lib/profanity_filter.rb#36
  def dictionary_file; end

  # source://profanity_filter//lib/profanity_filter.rb#36
  def dictionary_file=(val); end

  # source://profanity_filter//lib/profanity_filter.rb#36
  def replacement_text; end

  # source://profanity_filter//lib/profanity_filter.rb#36
  def replacement_text=(val); end

  class << self
    # @return [Boolean]
    #
    # source://profanity_filter//lib/profanity_filter.rb#45
    def banned?(word = T.unsafe(nil)); end

    # source://profanity_filter//lib/profanity_filter.rb#53
    def clean(text, replace_method = T.unsafe(nil)); end

    # source://profanity_filter//lib/profanity_filter.rb#59
    def clean_word(word); end

    # source://profanity_filter//lib/profanity_filter.rb#41
    def dictionary; end

    # source://profanity_filter//lib/profanity_filter.rb#36
    def dictionary=(val); end

    # source://profanity_filter//lib/profanity_filter.rb#36
    def dictionary_file; end

    # source://profanity_filter//lib/profanity_filter.rb#36
    def dictionary_file=(val); end

    # @return [Boolean]
    #
    # source://profanity_filter//lib/profanity_filter.rb#49
    def profane?(text = T.unsafe(nil)); end

    # source://profanity_filter//lib/profanity_filter.rb#71
    def replacement(word); end

    # source://profanity_filter//lib/profanity_filter.rb#36
    def replacement_text; end

    # source://profanity_filter//lib/profanity_filter.rb#36
    def replacement_text=(val); end
  end
end

# source://profanity_filter//lib/profanity_filter.rb#10
module ProfanityFilter::ClassMethods
  # source://profanity_filter//lib/profanity_filter.rb#16
  def profanity_filter(*attr_names); end

  # source://profanity_filter//lib/profanity_filter.rb#11
  def profanity_filter!(*attr_names); end

  # source://profanity_filter//lib/profanity_filter.rb#28
  def setup_callbacks_for(attr_name, option); end
end