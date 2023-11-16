# frozen_string_literal: true

module CacheStoreFormatVersionBehavior
  FORMAT_VERSIONS = [ 6.1, 7.0, 7.1 ]

  FORMAT_VERSIONS.each do |format_version|
    define_method "test_marshal_undefined_class_deserialization_error_with_format_#{format_version}" do
      with_format(format_version) do |cache|

        key = "marshal-#{rand}"
        self.class.const_set(:RemovedConstant, Class.new)

        value_to_compress = [ self.class::RemovedConstant.new, "0" * 100 ]
        cache.write(key, value_to_compress, compress: true, compress_threshold: 1)
        self.class.send(:remove_const, :RemovedConstant)
        assert_equal({}, cache.read_multi(key))
      end
    ensure
      self.class.send(:remove_const, :RemovedConstant) rescue nil
    end
  end

  private
    def with_format(format_version)
      if format_version == 6.1
        ActiveSupport.deprecator.silence do
          ActiveSupport::Cache.with(format_version: format_version) { yield lookup_store }
        end
      else
        ActiveSupport::Cache.with(format_version: format_version) { yield lookup_store }
      end
    end
end
