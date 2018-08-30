Dir[Rails.root.join('lib', 'proofer_mocks', '*')].each { |file| require file }
Idv::Proofer.validate_vendors!
