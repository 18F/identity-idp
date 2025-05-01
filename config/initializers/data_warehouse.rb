# frozen_string_literal: true

if IdentityConfig.store.data_warehouse_enabled
  ActiveRecord::Base.establish_connection(:data_warehouse)
end
