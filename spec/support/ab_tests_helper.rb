module AbTestsHelper
  def reload_ab_tests
    # rubocop:disable Rails/FindEach
    AbTests.all.each do |(name, _)|
      AbTests.send(:remove_const, name)
    end
    # rubocop:enable Rails/FindEach
    load('config/initializers/ab_tests.rb')
  end
end
