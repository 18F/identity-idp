class PasswordMetric < ApplicationRecord
  enum metric: %i[length guesses_log10]

  def self.increment(metric, value)
    create_row_for_metric_category(metric, value)
    sql = <<-SQL
      UPDATE password_metrics
      SET count = count + 1
      WHERE metric = #{metrics[metric.to_s]} AND value = #{value}
    SQL
    connection.execute(sql)
  end

  private_class_method def self.create_row_for_metric_category(metric, value)
    metric_key = metrics[metric.to_s]
    # Insert a row with the count equal to 0 if a row does not already exist
    sql = <<-SQL
      INSERT INTO password_metrics (metric, value, count)
      SELECT #{metric_key}, #{value}, 0
      WHERE NOT EXISTS (
        SELECT id FROM password_metrics WHERE metric = #{metric_key} AND value = #{value}
      )
    SQL
    connection.execute(sql)
  end
end
