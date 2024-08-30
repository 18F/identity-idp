module AbTestsHelper
  def reload_ab_tests
    AbTests.all.each do |(name, _)|
      AbTests.send(:remove_const, name)
    end
    load('config/initializers/ab_tests.rb')
  end
end
