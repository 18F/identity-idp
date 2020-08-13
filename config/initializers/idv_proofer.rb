Dir[Rails.root.join('lib', 'proofer_mocks', '*')].sort.each { |file| require file }
Idv::Proofer.validate_vendors!
