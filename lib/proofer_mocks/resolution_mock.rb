class ResolutionMock < Proofer::Base
  required_attributes :first_name, :ssn, :zipcode

  stage :resolution

  proof do |applicant, result|
    first_name = applicant[:first_name]

    raise 'Failed to contact proofing vendor' if first_name =~ /Fail/i

    if first_name.match?(/Bad/i)
      result.add_error(:first_name, 'Unverified first name.')

    elsif first_name.match?(/Time/i)
      raise Proofer::TimeoutError, 'resolution mock timeout'

    elsif applicant[:ssn].match?(/6666/)
      result.add_error(:ssn, 'Unverified SSN.')

    elsif applicant[:zipcode] == '00000'
      result.add_error(:zipcode, 'Unverified ZIP code.')
    end
  end
end
