module AbTestsHelper
  # Rebuilds the A/B tests from current config, including any stubs. Use this after
  # stubbing config to pick up the stubbed values.
  def reload_ab_tests
    # rubocop:disable Rails/FindEach
    AbTests.all.each do |(name, _)|
      AbTests.send(:remove_const, name)
    end
    # rubocop:enable Rails/FindEach
    load('config/initializers/ab_tests.rb')
  end

  # Config stubs are still active in after hooks. Remove them first so the A/B tests
  # are rebuilt from real config.
  def reload_ab_tests_with_real_config
    RSpec::Mocks.space.proxy_for(IdentityConfig.store).reset
    reload_ab_tests
  end
end
