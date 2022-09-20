module Idv
  class NativeCameraABTest < AbTestBucket
    def initialize
      buckets = {}
      if IdentityConfig.store.idv_native_camera_a_b_testing_enabled
        buckets = {
          native_camera_only: IdentityConfig.store.idv_native_camera_a_b_testing_percent,
        }
      end

      super(experiment_name: 'Native Camera Only', buckets: buckets)
    end
  end
end
