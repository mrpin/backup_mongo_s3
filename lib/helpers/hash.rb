class Hash

  def symbolize_keys!
    transform_keys! { |key| key.to_sym rescue key }
  end

  def deep_symbolize_keys!
    deep_transform_keys!{ |key| key.to_sym rescue key }
  end

  def transform_keys!
    keys.each do |key|
      self[yield(key)] = delete(key)
    end
    self
  end

  def deep_transform_keys!(&block)
    keys.each do |key|
      value = delete(key)
      self[yield(key)] = value.is_a?(Hash) ? value.deep_transform_keys!(&block) : value
    end
    self
  end

end