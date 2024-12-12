# typed: true

# DO NOT EDIT MANUALLY
# This file was pulled from a central RBI files repository.
# Please run `bin/tapioca annotations` to update it.

module Phonelib
  module Core
    sig { params(country: T.nilable(T.any(String, Symbol, T::Array[T.any(String, Symbol)]))).returns(T.nilable(T.any(String, Symbol, T::Array[T.any(String, Symbol)]))) }
    def default_country=(country); end

    sig { params(phone: String, passed_country: T.nilable(T.any(String, Symbol))).returns(Phonelib::Phone) }
    def parse(phone, passed_country = nil); end
  end

  class Phone
    sig { params(phone: String, country: T.nilable(T.any(String, Symbol))).void }
    def initialize(phone, country = nil); end

    sig { returns(T::Boolean) }
    def valid?; end

    sig { returns(T::Boolean) }
    def invalid?; end

    sig { returns(T::Boolean) }
    def possible?; end

    sig { returns(T::Boolean) }
    def impossible?; end
  end

  module PhoneFormatter
    sig { returns(T.nilable(String)) }
    def area_code; end

    sig { params(formatted: T::Boolean).returns(String) }
    def national(formatted = true); end

    sig { returns(String) }
    def country_code; end
  end
end
