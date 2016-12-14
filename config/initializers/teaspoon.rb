unless Rails.env.production?
  require 'teaspoon/suite_controller'

  module Teaspoon
    class SuiteController
      skip_before_filter :handle_two_factor_authentication
    end
  end
end
