module PivCac
  class IsFullNameInCn
    def self.call(cn, first_name, last_name)
      cn_downcase = cn.downcase
      cn_downcase.include?(first_name.downcase) && cn_downcase.include?(last_name.downcase)
    end
  end
end
