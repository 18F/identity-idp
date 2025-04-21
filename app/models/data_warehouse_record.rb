class DataWarehouseRecord < ActiveRecord::Base
  self.abstract_class = true

  if Rails.env.production?
    connects_to database: { reading: :data_warehouse }
  end
end
