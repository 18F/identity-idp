Ahoy.mount = false
Ahoy.throttle = false
# Period of inactivity before a new visit is created
Ahoy.visit_duration = 30.minutes

module Ahoy
  class Store < Ahoy::Stores::LogStore
    def exclude?
      return if FeatureManagement.enable_load_testing_mode?
      super
    end
  end
end
