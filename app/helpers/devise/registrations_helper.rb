module Devise
  module RegistrationsHelper
    def account_type_label(opt)
      opt[0].html_safe
    end
  end
end
