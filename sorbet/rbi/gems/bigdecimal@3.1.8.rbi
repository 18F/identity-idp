# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `bigdecimal` gem.
# Please instead update this file by running `bin/tapioca gem bigdecimal`.


# source://bigdecimal//lib/bigdecimal/util.rb#78
class BigDecimal < ::Numeric
  # call-seq:
  #     a.to_d -> bigdecimal
  #
  # Returns self.
  #
  #     require 'bigdecimal/util'
  #
  #     d = BigDecimal("3.14")
  #     d.to_d                       # => 0.314e1
  #
  # source://bigdecimal//lib/bigdecimal/util.rb#110
  def to_d; end

  # call-seq:
  #     a.to_digits -> string
  #
  # Converts a BigDecimal to a String of the form "nnnnnn.mmm".
  # This method is deprecated; use BigDecimal#to_s("F") instead.
  #
  #     require 'bigdecimal/util'
  #
  #     d = BigDecimal("3.14")
  #     d.to_digits                  # => "3.14"
  #
  # source://bigdecimal//lib/bigdecimal/util.rb#90
  def to_digits; end
end

BigDecimal::VERSION = T.let(T.unsafe(nil), String)

# source://bigdecimal//lib/bigdecimal/util.rb#138
class Complex < ::Numeric
  # call-seq:
  #     cmp.to_d             -> bigdecimal
  #     cmp.to_d(precision)  -> bigdecimal
  #
  # Returns the value as a BigDecimal.
  #
  # The +precision+ parameter is required for a rational complex number.
  # This parameter is used to determine the number of significant digits
  # for the result.
  #
  #     require 'bigdecimal'
  #     require 'bigdecimal/util'
  #
  #     Complex(0.1234567, 0).to_d(4)   # => 0.1235e0
  #     Complex(Rational(22, 7), 0).to_d(3)   # => 0.314e1
  #
  # See also Kernel.BigDecimal.
  #
  # source://bigdecimal//lib/bigdecimal/util.rb#157
  def to_d(*args); end
end

# source://bigdecimal//lib/bigdecimal/util.rb#171
class NilClass
  # call-seq:
  #     nil.to_d -> bigdecimal
  #
  # Returns nil represented as a BigDecimal.
  #
  #     require 'bigdecimal'
  #     require 'bigdecimal/util'
  #
  #     nil.to_d   # => 0.0
  #
  # source://bigdecimal//lib/bigdecimal/util.rb#182
  def to_d; end
end
