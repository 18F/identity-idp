module ContentHelper
  def split_tag(value, delimiter)
    if value.is_a? Array
      return value unless value.join.include? delimiter
      value.flat_map { |str| str.partition(delimiter) }.reject(&:empty?)
    else
      value.to_s.partition(delimiter).reject(&:empty?)
    end
  end
end
