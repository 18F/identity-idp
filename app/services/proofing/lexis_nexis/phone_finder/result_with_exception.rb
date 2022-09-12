module Proofing
  module LexisNexis
    module PhoneFinder
      # TODO: Test me pls
      class ResultWithException
        attr_reader :exception

        def initialize(exception)
          @exception = exception
        end

        def success?
          false
        end

        def errors
          {}
        end

        def timed_out?
          exception.is_a?(Proofing::TimeoutError)
        end

        def to_h
          {
            success: success?,
            errors: errors,
            exception: exception,
            timed_out: timed_out?,
            vendor_name: 'lexisnexis:phone_finder',
          }
        end
      end
    end
  end
end
