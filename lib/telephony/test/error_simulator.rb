# frozen_string_literal: true

module Telephony
  module Test
    class ErrorSimulator
      OPT_OUT_PHONE_NUMBER = '2255559999'

      def error_for_number(number)
        cleaned_number = number.gsub(/^\+1/, '').gsub(/\D/, '')
        case cleaned_number
        when '2255551000'
          TelephonyError.new('Simulated telephony error')
        when '225555300'
          InvalidPhoneNumberError.new('Simulated phone number error')
        when '2255552000'
          InvalidCallingAreaError.new('Simulated calling area error')
        when OPT_OUT_PHONE_NUMBER
          OptOutError.new('Simulated opt out error')
        end
      end
    end
  end
end
