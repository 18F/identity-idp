module XPathHelper
  def generate_class_selector(klass)
    "*[contains(concat(' ', normalize-space(@class), ' '), ' #{klass} ')]"
  end
end
