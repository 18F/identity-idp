class AddPostgisExtensionToDatabase < ActiveRecord::Migration[7.0]
  def change
    # In the time since we added this extension, we have removed it and
    # also removed the postgis-compatible images from our CI pipeline,
    # so running this old migration fails
    # enable_extension 'postgis'
  end
end
