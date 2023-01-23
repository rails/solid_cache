# frozen_string_literal: true

# Tests the base functionality that should be identical across all cache stores.
module CacheStoreBehavior
  def test_should_read_and_write_strings
    key = SecureRandom.uuid
    assert @cache.write(key, "bar")
    assert_equal "bar", @cache.read(key)
  end

  def test_should_overwrite
    key = SecureRandom.uuid
    @cache.write(key, "bar")
    @cache.write(key, "baz")
    assert_equal "baz", @cache.read(key)
  end

  def test_fetch_without_cache_miss
    key = SecureRandom.uuid
    @cache.write(key, "bar")
    assert_not_called(@cache, :write) do
      assert_equal "bar", @cache.fetch(key) { "baz" }
    end
  end

  def test_fetch_with_cache_miss
    key = SecureRandom.uuid
    assert_called_with(@cache, :write, [key, "baz", @cache.options]) do
      assert_equal "baz", @cache.fetch(key) { "baz" }
    end
  end

  def test_fetch_with_cache_miss_passes_key_to_block
    cache_miss = false
    key = SecureRandom.alphanumeric(10)
    assert_equal 10, @cache.fetch(key) { |key| cache_miss = true; key.length }
    assert cache_miss

    cache_miss = false
    assert_equal 10, @cache.fetch(key) { |fetch_key| cache_miss = true; fetch_key.length }
    assert_not cache_miss
  end

  def test_fetch_with_forced_cache_miss
    key = SecureRandom.uuid
    @cache.write(key, "bar")
    assert_not_called(@cache, :read) do
      assert_called_with(@cache, :write, [key, "bar", @cache.options.merge(force: true)]) do
        @cache.fetch(key, force: true) { "bar" }
      end
    end
  end

  def test_fetch_with_cached_nil
    key = SecureRandom.uuid
    @cache.write(key, nil)
    assert_not_called(@cache, :write) do
      assert_nil @cache.fetch(key) { "baz" }
    end
  end

  def test_fetch_cache_miss_with_skip_nil
    key = SecureRandom.uuid
    assert_not_called(@cache, :write) do
      assert_nil @cache.fetch(key, skip_nil: true) { nil }
      assert_equal false, @cache.exist?("foo")
    end
  end

  def test_fetch_with_forced_cache_miss_with_block
    key = SecureRandom.uuid
    @cache.write(key, "bar")
    assert_equal "foo_bar", @cache.fetch(key, force: true) { "foo_bar" }
  end

  def test_fetch_with_forced_cache_miss_without_block
    key = SecureRandom.uuid
    @cache.write(key, "bar")
    assert_raises(ArgumentError) do
      @cache.fetch(key, force: true)
    end

    assert_equal "bar", @cache.read(key)
  end

  def test_should_read_and_write_hash
    key = SecureRandom.uuid
    assert @cache.write(key, a: "b")
    assert_equal({ a: "b" }, @cache.read(key))
  end

  def test_should_read_and_write_integer
    key = SecureRandom.uuid
    assert @cache.write(key, 1)
    assert_equal 1, @cache.read(key)
  end

  def test_should_read_and_write_nil
    key = SecureRandom.uuid
    assert @cache.write(key, nil)
    assert_nil @cache.read(key)
  end

  def test_should_read_and_write_false
    key = SecureRandom.uuid
    assert @cache.write(key, false)
    assert_equal false, @cache.read(key)
  end

  def test_read_multi
    key = SecureRandom.uuid
    @cache.write(key, "bar")
    other_key = SecureRandom.uuid
    @cache.write(other_key, "baz")
    @cache.write(SecureRandom.alphanumeric, "biz")
    assert_equal({ key => "bar", other_key => "baz" }, @cache.read_multi(key, other_key))
  end

  def test_read_multi_with_expires
    time = Time.now
    key = SecureRandom.uuid
    other_key = SecureRandom.uuid
    @cache.write(key, "bar", expires_in: 10)
    @cache.write(other_key, "baz")
    @cache.write(SecureRandom.alphanumeric, "biz")
    Time.stub(:now, time + 11) do
      assert_equal({ other_key => "baz" }, @cache.read_multi(other_key, SecureRandom.alphanumeric))
    end
  end

  def test_read_multi_with_empty_keys_and_a_logger_and_no_namespace
    cache = lookup_store(namespace: nil)
    cache.logger = ActiveSupport::Logger.new(nil)
    assert_equal({}, cache.read_multi)
  end

  def test_fetch_multi
    key = SecureRandom.uuid
    other_key = SecureRandom.uuid
    third_key = SecureRandom.alphanumeric
    @cache.write(key, "bar")
    @cache.write(other_key, "biz")

    values = @cache.fetch_multi(key, other_key, third_key) { |value| value * 2 }

    assert_equal({ key => "bar", other_key => "biz", third_key => (third_key * 2) }, values)
    assert_equal((third_key * 2), @cache.read(third_key))
  end

  def test_fetch_multi_without_expires_in
    key = SecureRandom.uuid
    other_key = SecureRandom.uuid
    third_key = SecureRandom.alphanumeric
    @cache.write(key, "bar")
    @cache.write(other_key, "biz")

    values = @cache.fetch_multi(key, third_key, other_key, expires_in: nil) { |value| value * 2 }

    assert_equal({ key => "bar", third_key => (third_key * 2), other_key => "biz" }, values)
    assert_equal((third_key * 2), @cache.read(third_key))
  end

  def test_fetch_multi_with_objects
    key = SecureRandom.uuid
    other_key = SecureRandom.uuid
    cache_struct = Struct.new(:cache_key, :title)
    foo = cache_struct.new(key, "FOO!")
    bar = cache_struct.new(other_key)

    @cache.write(other_key, "BAM!")

    values = @cache.fetch_multi(foo, bar) { |object| object.title }

    assert_equal({ foo => "FOO!", bar => "BAM!" }, values)
  end

  def test_fetch_multi_returns_ordered_names
    key = SecureRandom.alphanumeric.downcase
    other_key = SecureRandom.alphanumeric.downcase
    third_key = SecureRandom.alphanumeric.downcase
    @cache.write(key, "BAM")

    values = @cache.fetch_multi(other_key, third_key, key) { |key| key.upcase }

    assert_equal([other_key, third_key, key], values.keys)
    assert_equal([other_key.upcase, third_key.upcase, "BAM"], values.values)
  end

  def test_fetch_multi_without_block
    assert_raises(ArgumentError) do
      @cache.fetch_multi(SecureRandom.alphanumeric)
    end
  end

  # Use strings that are guaranteed to compress well, so we can easily tell if
  # the compression kicked in or not.
  SMALL_STRING = "0" * 100
  LARGE_STRING = "0" * 2.kilobytes

  SMALL_OBJECT = { data: SMALL_STRING }
  LARGE_OBJECT = { data: LARGE_STRING }

  def test_nil_with_default_compression_settings
    assert_uncompressed(nil)
  end

  def test_nil_with_compress_true
    assert_uncompressed(nil, compress: true)
  end

  def test_nil_with_compress_false
    assert_uncompressed(nil, compress: false)
  end

  def test_nil_with_compress_low_compress_threshold
    assert_uncompressed(nil, compress: true, compress_threshold: 20)
  end

  def test_small_string_with_default_compression_settings
    assert_uncompressed(SMALL_STRING)
  end

  def test_small_string_with_compress_true
    assert_uncompressed(SMALL_STRING, compress: true)
  end

  def test_small_string_with_compress_false
    assert_uncompressed(SMALL_STRING, compress: false)
  end

  def test_small_string_with_low_compress_threshold
    assert_compressed(SMALL_STRING, compress: true, compress_threshold: 1)
  end

  def test_small_object_with_default_compression_settings
    assert_uncompressed(SMALL_OBJECT)
  end

  def test_small_object_with_compress_true
    assert_uncompressed(SMALL_OBJECT, compress: true)
  end

  def test_small_object_with_compress_false
    assert_uncompressed(SMALL_OBJECT, compress: false)
  end

  def test_small_object_with_low_compress_threshold
    assert_compressed(SMALL_OBJECT, compress: true, compress_threshold: 1)
  end

  def test_large_string_with_compress_true
    assert_compressed(LARGE_STRING, compress: true)
  end

  def test_large_string_with_compress_false
    assert_uncompressed(LARGE_STRING, compress: false)
  end

  def test_large_string_with_high_compress_threshold
    assert_uncompressed(LARGE_STRING, compress: true, compress_threshold: 1.megabyte)
  end

  def test_large_object_with_compress_true
    assert_compressed(LARGE_OBJECT, compress: true)
  end

  def test_large_object_with_compress_false
    assert_uncompressed(LARGE_OBJECT, compress: false)
  end

  def test_large_object_with_high_compress_threshold
    assert_uncompressed(LARGE_OBJECT, compress: true, compress_threshold: 1.megabyte)
  end

  def test_incompressible_data
    assert_uncompressed(nil, compress: true, compress_threshold: 30)
    assert_uncompressed(true, compress: true, compress_threshold: 30)
    assert_uncompressed(false, compress: true, compress_threshold: 30)
    assert_uncompressed(0, compress: true, compress_threshold: 30)
    assert_uncompressed(1.2345, compress: true, compress_threshold: 30)
    assert_uncompressed("", compress: true, compress_threshold: 30)

    incompressible = nil

    # generate an incompressible string
    loop do
      incompressible = Random.bytes(1.kilobyte)
      break if incompressible.bytesize < Zlib::Deflate.deflate(incompressible).bytesize
    end

    assert_uncompressed(incompressible, compress: true, compress_threshold: 1)
  end

  def test_cache_key
    key = SecureRandom.uuid
    klass = Class.new do
      def initialize(key)
        @key = key
      end
      def cache_key
        @key
      end
    end
    @cache.write(klass.new(key), "bar")
    assert_equal "bar", @cache.read(key)
  end

  def test_param_as_cache_key
    key = SecureRandom.uuid
    klass = Class.new do
      def initialize(key)
        @key = key
      end
      def to_param
        @key
      end
    end
    @cache.write(klass.new(key), "bar")
    assert_equal "bar", @cache.read(key)
  end

  def test_unversioned_cache_key
    key = SecureRandom.uuid
    klass = Class.new do
      def initialize(key)
        @key = key
      end
      def cache_key
        @key
      end
      def cache_key_with_version
        "#{@key}-v1"
      end
    end
    @cache.write(klass.new(key), "bar")
    assert_equal "bar", @cache.read(key)
  end

  def test_array_as_cache_key
    key = SecureRandom.uuid
    @cache.write([key, "foo"], "bar")
    assert_equal "bar", @cache.read("#{key}/foo")
  end

  InstanceTest = Struct.new(:name, :id) do
    def cache_key
      "#{name}/#{id}"
    end

    def to_param
      "hello"
    end
  end

  def test_array_with_single_instance_as_cache_key_uses_cache_key_method
    key = SecureRandom.alphanumeric
    other_key = SecureRandom.alphanumeric
    test_instance_one = InstanceTest.new(key, 1)
    test_instance_two = InstanceTest.new(other_key, 2)

    @cache.write([test_instance_one], "one")
    @cache.write([test_instance_two], "two")

    assert_equal "one", @cache.read([test_instance_one])
    assert_equal "two", @cache.read([test_instance_two])
  end

  def test_array_with_multiple_instances_as_cache_key_uses_cache_key_method
    key = SecureRandom.alphanumeric
    other_key = SecureRandom.alphanumeric
    third_key = SecureRandom.alphanumeric
    test_instance_one = InstanceTest.new(key, 1)
    test_instance_two = InstanceTest.new(other_key, 2)
    test_instance_three = InstanceTest.new(third_key, 3)

    @cache.write([test_instance_one, test_instance_three], "one")
    @cache.write([test_instance_two, test_instance_three], "two")

    assert_equal "one", @cache.read([test_instance_one, test_instance_three])
    assert_equal "two", @cache.read([test_instance_two, test_instance_three])
  end

  def test_format_of_expanded_key_for_single_instance
    key = SecureRandom.alphanumeric
    test_instance_one = InstanceTest.new(key, 1)

    expanded_key = @cache.send(:expanded_key, test_instance_one)

    assert_equal expanded_key, test_instance_one.cache_key
  end

  def test_format_of_expanded_key_for_single_instance_in_array
    key = SecureRandom.alphanumeric
    test_instance_one = InstanceTest.new(key, 1)

    expanded_key = @cache.send(:expanded_key, [test_instance_one])

    assert_equal expanded_key, test_instance_one.cache_key
  end

  def test_hash_as_cache_key
    key = SecureRandom.alphanumeric
    other_key = SecureRandom.alphanumeric
    @cache.write({ key => 1, other_key => 2 }, "bar")
    assert_equal "bar", @cache.read({ key => 1, other_key => 2 })
  end

  def test_keys_are_case_sensitive
    key = SecureRandom.alphanumeric
    @cache.write(key, "bar")
    assert_nil @cache.read(key.upcase)
  end

  def test_exist
    key = SecureRandom.alphanumeric
    @cache.write(key, "bar")
    assert_equal true, @cache.exist?(key)
    assert_equal false, @cache.exist?(SecureRandom.uuid)
  end

  def test_nil_exist
    key = SecureRandom.alphanumeric
    @cache.write(key, nil)
    assert @cache.exist?(key)
  end

  def test_delete
    key = SecureRandom.alphanumeric
    @cache.write(key, "bar")
    assert @cache.exist?(key)
    assert @cache.delete(key)
    assert_not @cache.exist?(key)
  end

  def test_delete_multi
    key = SecureRandom.alphanumeric
    @cache.write(key, "bar")
    assert @cache.exist?(key)
    other_key = SecureRandom.alphanumeric
    @cache.write(other_key, "world")
    assert @cache.exist?(other_key)
    assert_equal 2, @cache.delete_multi([key, SecureRandom.uuid, other_key])
    assert_not @cache.exist?(key)
    assert_not @cache.exist?(other_key)
  end

  def test_original_store_objects_should_not_be_immutable
    bar = +"bar"
    key = SecureRandom.alphanumeric
    @cache.write(key, bar)
    assert_nothing_raised { bar.gsub!(/.*/, "baz") }
  end

  def test_expires_in
    time = Time.local(2008, 4, 24)

    key = SecureRandom.alphanumeric
    other_key = SecureRandom.alphanumeric

    Time.stub(:now, time) do
      @cache.write(key, "bar", expires_in: 1.minute)
      @cache.write(other_key, "spam", expires_in: 2.minute)
      assert_equal "bar", @cache.read(key)
      assert_equal "spam", @cache.read(other_key)
    end

    Time.stub(:now, time + 30) do
      assert_equal "bar", @cache.read(key)
      assert_equal "spam", @cache.read(other_key)
    end

    Time.stub(:now, time + 1.minute + 1.second) do
      assert_nil @cache.read(key)
      assert_equal "spam", @cache.read(other_key)
    end

    Time.stub(:now, time + 2.minute + 1.second) do
      assert_nil @cache.read(key)
      assert_nil @cache.read(other_key)
    end
  end

  def test_expires_at
    time = Time.local(2008, 4, 24)

    key = SecureRandom.alphanumeric
    Time.stub(:now, time) do
      @cache.write(key, "bar", expires_at: time + 15.seconds)
      assert_equal "bar", @cache.read(key)
    end

    Time.stub(:now, time + 10) do
      assert_equal "bar", @cache.read(key)
    end

    Time.stub(:now, time + 30) do
      assert_nil @cache.read(key)
    end
  end

  def test_expire_in_is_alias_for_expires_in
    time = Time.local(2008, 4, 24)

    key = SecureRandom.alphanumeric
    Time.stub(:now, time) do
      @cache.write(key, "bar", expire_in: 20)
      assert_equal "bar", @cache.read(key)
    end

    Time.stub(:now, time + 10) do
      assert_equal "bar", @cache.read(key)
    end

    Time.stub(:now, time + 21) do
      assert_nil @cache.read(key)
    end
  end

  def test_expired_in_is_alias_for_expires_in
    time = Time.local(2008, 4, 24)

    key = SecureRandom.alphanumeric
    Time.stub(:now, time) do
      @cache.write(key, "bar", expired_in: 20)
      assert_equal "bar", @cache.read(key)
    end

    Time.stub(:now, time + 10) do
      assert_equal "bar", @cache.read(key)
    end

    Time.stub(:now, time + 21) do
      assert_nil @cache.read(key)
    end
  end

  def test_race_condition_protection_skipped_if_not_defined
    key = SecureRandom.alphanumeric
    @cache.write(key, "bar")
    time = @cache.send(:read_entry, @cache.send(:normalize_key, key, {}), **{}).expires_at

    Time.stub(:now, Time.at(time)) do
      result = @cache.fetch(key) do
        assert_nil @cache.read(key)
        "baz"
      end
      assert_equal "baz", result
    end
  end

  def test_race_condition_protection_is_limited
    time = Time.now
    key = SecureRandom.uuid
    @cache.write(key, "bar", expires_in: 60)
    Time.stub(:now, time + 71) do
      result = @cache.fetch(key, race_condition_ttl: 10) do
        assert_nil @cache.read(key)
        "baz"
      end
      assert_equal "baz", result
    end
  end

  def test_race_condition_protection_is_safe
    time = Time.now
    key = SecureRandom.uuid
    @cache.write(key, "bar", expires_in: 60)
    Time.stub(:now, time + 61) do
      begin
        @cache.fetch(key, race_condition_ttl: 10) do
          assert_equal "bar", @cache.read(key)
          raise ArgumentError.new
        end
      rescue ArgumentError
      end
      assert_equal "bar", @cache.read(key)
    end
    Time.stub(:now, time + 91) do
      assert_nil @cache.read(key)
    end
  end

  def test_race_condition_protection
    time = Time.now
    key = SecureRandom.uuid
    @cache.write(key, "bar", expires_in: 60)
    Time.stub(:now, time + 61) do
      result = @cache.fetch(key, race_condition_ttl: 10) do
        assert_equal "bar", @cache.read(key)
        "baz"
      end
      assert_equal "baz", result
    end
  end

  def test_absurd_key_characters
    absurd_key = "#/:*(<+=> )&$%@?;'\"\'`~-"
    assert @cache.write(absurd_key, "1", raw: true)
    assert_equal "1", @cache.read(absurd_key, raw: true)
    assert_equal "1", @cache.fetch(absurd_key, raw: true)
    assert @cache.delete(absurd_key)
    assert_equal "2", @cache.fetch(absurd_key, raw: true) { "2" }
    assert_equal 3, @cache.increment(absurd_key)
    assert_equal 2, @cache.decrement(absurd_key)
  end

  def test_really_long_keys
    key = SecureRandom.alphanumeric * 2048
    assert @cache.write(key, "bar")
    assert_equal "bar", @cache.read(key)
    assert_equal "bar", @cache.fetch(key)
    assert_nil @cache.read("#{key}x")
    assert_equal({ key => "bar" }, @cache.read_multi(key))
  end

  def test_cache_hit_instrumentation
    key = "test_key"
    @events = []
    ActiveSupport::Notifications.subscribe "cache_read.active_support" do |*args|
      @events << ActiveSupport::Notifications::Event.new(*args)
    end
    assert @cache.write(key, "1", raw: true)
    assert @cache.fetch(key, raw: true) { }
    assert_equal 1, @events.length
    assert_equal "cache_read.active_support", @events[0].name
    assert_equal :fetch, @events[0].payload[:super_operation]
    assert @events[0].payload[:hit]
  ensure
    ActiveSupport::Notifications.unsubscribe "cache_read.active_support"
  end

  def test_cache_miss_instrumentation
    @events = []
    ActiveSupport::Notifications.subscribe(/^cache_(.*)\.active_support$/) do |*args|
      @events << ActiveSupport::Notifications::Event.new(*args)
    end
    assert_not @cache.fetch(SecureRandom.uuid) { }
    assert_equal 3, @events.length
    assert_equal "cache_read.active_support", @events[0].name
    assert_equal "cache_generate.active_support", @events[1].name
    assert_equal "cache_write.active_support", @events[2].name
    assert_equal :fetch, @events[0].payload[:super_operation]
    assert_not @events[0].payload[:hit]
  ensure
    ActiveSupport::Notifications.unsubscribe "cache_read.active_support"
  end

  private
    def assert_compressed(value, **options)
      assert_compression(true, value, **options)
    end

    def assert_uncompressed(value, **options)
      assert_compression(false, value, **options)
    end

    def assert_compression(should_compress, value, **options)
      actual = "actual" + SecureRandom.uuid
      uncompressed = "uncompressed" + SecureRandom.uuid

      freeze_time do
        @cache.write(actual, value, options)
        @cache.write(uncompressed, value, options.merge(compress: false))
      end

      if value.nil?
        assert_nil @cache.read(actual)
        assert_nil @cache.read(uncompressed)
      else
        assert_equal value, @cache.read(actual)
        assert_equal value, @cache.read(uncompressed)
      end

      actual_entry = @cache.send(:read_entry, @cache.send(:normalize_key, actual, {}), **{})
      uncompressed_entry = @cache.send(:read_entry, @cache.send(:normalize_key, uncompressed, {}), **{})

      actual_payload = @cache.send(:serialize_entry, actual_entry, **@cache.send(:merged_options, options))
      uncompressed_payload = @cache.send(:serialize_entry, uncompressed_entry, compress: false)

      actual_size = actual_payload.bytesize
      uncompressed_size = uncompressed_payload.bytesize

      if should_compress
        assert_operator actual_size, :<, uncompressed_size, "value should be compressed"
      else
        assert_equal uncompressed_size, actual_size, "value should not be compressed"
      end
    end
end
