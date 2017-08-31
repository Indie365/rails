# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

class Mysql2TableOptionsTest < ActiveRecord::Mysql2TestCase
  include SchemaDumpingHelper

  def setup
    @connection = ActiveRecord::Base.connection
  end

  def teardown
    @connection.drop_table "mysql_table_options", if_exists: true
  end

  test "table options with ENGINE" do
    @connection.create_table "mysql_table_options", force: true, options: "ENGINE=MyISAM"
    output = dump_table_schema("mysql_table_options")
    options = %r{create_table "mysql_table_options", options: "(?<options>.*)"}.match(output)[:options]
    assert_match %r{ENGINE=MyISAM}, options
  end

  test "table options with ROW_FORMAT" do
    @connection.create_table "mysql_table_options", force: true, options: "ROW_FORMAT=REDUNDANT"
    output = dump_table_schema("mysql_table_options")
    options = %r{create_table "mysql_table_options", options: "(?<options>.*)"}.match(output)[:options]
    assert_match %r{ROW_FORMAT=REDUNDANT}, options
  end

  test "table options with CHARSET" do
    @connection.create_table "mysql_table_options", force: true, options: "CHARSET=utf8mb4"
    output = dump_table_schema("mysql_table_options")
    options = %r{create_table "mysql_table_options", options: "(?<options>.*)"}.match(output)[:options]
    assert_match %r{CHARSET=utf8mb4}, options
  end

  test "table options with COLLATE" do
    @connection.create_table "mysql_table_options", force: true, options: "COLLATE=utf8mb4_bin"
    output = dump_table_schema("mysql_table_options")
    options = %r{create_table "mysql_table_options", options: "(?<options>.*)"}.match(output)[:options]
    assert_match %r{COLLATE=utf8mb4_bin}, options
  end
end
