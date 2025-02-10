# frozen_string_literal: true

module AbTestingConcern
  # @param [Symbol] test Name of the test, which should correspond to an A/B test defined in
  # #                    config/initializer/ab_tests.rb.
  # @return [Symbol,nil] Bucket to use for the given test, or nil if the test is not active.
  def ab_test_bucket(test_name, user: current_user)
    test = AbTests.all[test_name]
    raise "Unknown A/B test: #{test_name}" unless test

    test.bucket(
      request:,
      service_provider: current_sp&.issuer,
      session:,
      user:,
      user_session:,
    )
  end
end
