require "helper"
require "fluent/plugin/buf_memory"
begin
  require "snappy"
rescue LoadError
end

class CompressorTest < Test::Unit::TestCase
  class Snappy < self

    CONFIG = %[
      host namenode.local
      path /hdfs/path/file.%Y%m%d.log
    ]

    def setup
      omit unless Object.const_defined?(:Snappy)
      Fluent::Test.setup
      @compressor = Fluent::Plugin::WebHDFSOutput::SnappyCompressor.new
    end

    def create_driver(conf = CONFIG)
      Fluent::Test::Driver::Output.new(Fluent::Plugin::WebHDFSOutput).configure(conf)
    end

    def test_ext
      assert_equal(".sz", @compressor.ext)
    end

    def test_compress
      d = create_driver
      if d.instance.respond_to?(:buffer)
        buffer = d.instance.buffer
      else
        buffer = d.instance.instance_variable_get(:@buffer)
      end

      if buffer.respond_to?(:generate_chunk)
        chunk = buffer.generate_chunk("test")
        chunk.concat("hello snappy\n" * 32 * 1024, 1)
      else
        chunk = buffer.new_chunk("test")
        chunk << "hello snappy\n" * 32 * 1024
      end

      io = Tempfile.new("snappy-")
      @compressor.compress(chunk, io)
      io.open
      chunk_bytesize = chunk.respond_to?(:bytesize) ? chunk.bytesize : chunk.size
      assert(chunk_bytesize > io.read.bytesize)
      io.rewind
      reader = ::Snappy::Reader.new(io)
      assert_equal(chunk.read, reader.read)
      io.close
    end
  end
end

