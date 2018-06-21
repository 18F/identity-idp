class PasswordMetric < ApplicationRecord
  enum metric: %i[length guesses_log10]

  def self.increment(metric, value)
    create_row_for_metric_category(metric, value)
    query = <<-SQL
      UPDATE password_metrics
      SET count = count + 1
      WHERE metric = ? AND value = ?
    SQL
    sanitized_query = sanitize_sql_array([query, metrics[metric.to_s], value])
    connection.execute(sanitized_query)
  end

  private_class_method def self.create_row_for_metric_category(metric, value)
    metric_key = metrics[metric.to_s]
    # Insert a row with the count equal to 0 if a row does not already exist
    query = <<-SQL
      INSERT INTO password_metrics (metric, value, count)
      SELECT ?, ?, 0
      WHERE NOT EXISTS (
        SELECT id FROM password_metrics WHERE metric = ? AND value = ?
      )
    SQL
    sanitized_query = sanitize_sql_array([query, metric_key, value, metric_key, value])
    connection.execute(sanitized_query)
  end
end
