RSpec.configure do |c|
  c.around(:all) do |ex|
    next if c.instance_variable_get(:@files_or_directories_to_run) != ['spec']
    keys = IdentityConfig.store.to_h.keys
    RSpec::Mocks.with_temporary_scope do
      keys.each do |key|
        expect(IdentityConfig.store).to(
          receive(key),
          "Configuration key #{key} is unused and should be removed",
        )
      end

      ex.run
    end
  end
end
