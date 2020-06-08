module PivCac
  class SanitizeCn
    def self.call(subject)
      subject.gsub(/[A-Z]/, 'A').gsub(/[a-z]/, 'a').gsub(/[0-9]/, 'N')
    end
  end
end
