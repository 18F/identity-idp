class LoadEmailData < ActiveRecord::Migration[7.0]
  def change
    ActiveRecord::Base.connection.execute <<~PG
      COPY disposable_domains (name)
      FROM '#{EmailData.data_dir.join('disposable_domains')}.txt'
      (FORMAT CSV)
    PG
  end
end
