module Idv
  module Proofer
    module Mocks
      class ResolutionMock < ::Proofer::Base
        attributes :first_name, :ssn, :zipcode

        stage :resolution

        proof do |applicant, result|
          first_name = applicant[:first_name]
          case
          when first_name =~ /Fail/i
            raise 'Failed to contact proofing vendor'

          when first_name =~ /Bad/i
            result.add_error(:first_name, 'Unverified first name.')

          when applicant[:ssn] =~ /6666/
            result.add_error(:ssn, 'Unverified SSN.')

          when looks_like_bad_zipcode(applicant)
            result.add_error(:zipcode, 'Unverified ZIP code.')
          end
        end

        def looks_like_bad_zipcode(applicant)
          applicant[:zipcode] == '00000'
        end
      end
    end
  end
end
