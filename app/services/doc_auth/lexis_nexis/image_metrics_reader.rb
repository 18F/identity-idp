# frozen_string_literal: true

module DocAuth
  module LexisNexis
    module ImageMetricsReader
      private

      def read_image_metrics(true_id_product)
        image_metrics = {}
        return image_metrics unless true_id_product&.dig(:ParameterDetails).present?
        true_id_product[:ParameterDetails].each do |detail|
          next unless detail[:Group] == 'IMAGE_METRICS_RESULT'

          inner_val = detail.dig(:Values).map { |value| value.dig(:Value) }
          image_metrics[detail[:Name]] = inner_val
        end

        transform_metrics(image_metrics)
      end

      def transform_metrics(img_metrics)
        new_metrics = {}
        img_metrics['Side']&.each_with_index do |side, i|
          new_metrics[side.downcase.to_sym] = img_metrics.transform_values { |v| v[i] }
        end

        new_metrics
      end
    end
  end
end
