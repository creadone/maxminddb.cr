require "./any"
require "./decoder"
require "benchmark"

module MaxMindDB
  struct Metadata
    private METADATA_START_MARKER = "\xAB\xCD\xEFMaxMind.com".to_slice

    getter ip_version : Int32, node_count : Int32, record_size : Int32,
           build_time : Time, database_type : String, languages : Array(String),
           description : Hash(String, String), node_byte_size : Int32,
           search_tree_size : Int32, record_byte_size : Int32,
           tree_depth : Int32, version : String

    def initialize(buffer : Bytes)
      offset = find_start(buffer)
      raise InvalidDatabaseException.new("Can't parse binary database") if offset.zero?

      metadata = Decoder.new(buffer, offset).decode(offset).to_any
      raise InvalidDatabaseException.new("Can't parse binary database") if metadata.empty?

      @ip_version = metadata["ip_version"].as_i
      @node_count = metadata["node_count"].as_i
      @record_size = metadata["record_size"].as_i

      unless [24, 28, 32].includes?(@record_size)
        raise InvalidDatabaseException.new("Unsupported record size")
      end

      @build_time = Time.unix(metadata["build_epoch"].as_i)
      @database_type = metadata["database_type"].as_s
      @description = metadata["description"].as_h.transform_values &.as_s
      @languages = metadata["languages"].as_a.map &.as_s

      @node_byte_size = @record_size / 4
      @search_tree_size = @node_count * @node_byte_size
      @record_byte_size = @node_byte_size / 2
      @tree_depth = 2 ** (@ip_version + 1) # 32 for IPv4 and 128 for IPv6

      @version = [
        metadata["binary_format_major_version"].as_i,
        metadata["binary_format_minor_version"].as_i,
      ].join('.')
    end

    private def find_start(buffer : Bytes) : Int32
      marker_size  = METADATA_START_MARKER.size
      start_offset = buffer.size - marker_size
      found_offset = 0

      (0...start_offset).reverse_each do |i|
        found_offset = i if buffer[i, marker_size] == METADATA_START_MARKER
      end

      found_offset + marker_size
    end
  end
end
