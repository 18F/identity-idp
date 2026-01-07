# frozen_string_literal: true

module AbTestingConcern
  # @param [Symbol] test Name of the test, which should correspond to an A/B test defined in
  # #                    config/initializer/ab_tests.rb.
  # @return [Symbol,nil] Bucket to use for the given test, or nil if the test is not active.
  def ab_test_bucket(
    test_name,
    user: current_user,
    service_provider: current_sp&.issuer,
    current_session: session,
    current_user_session: user_session,
    request: nil # no a/b test currently use the request
  )
    test = AbTests.all[test_name]
    raise "Unknown A/B test: #{test_name}" unless test

    test.bucket(
      user:,
      service_provider:,
      session: current_session,
      user_session: current_user_session,
      request:,
    )
  end
end
