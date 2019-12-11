# :reek:ControlParameter
module PivCac
  class CnFieldsFromSubject
    def self.call(subject)
      # C=US, O=U.S. Government, OU=DoD, OU=PKI, OU=CONTRACTOR, CN=DOE.JANE.Q.123456
      subject =~ /CN=(.+)/ ? Regexp.last_match(0).split('.') : []
    end
  end
end
