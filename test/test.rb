#!/usr/bin/env ruby

# environment file
require File.join(File.dirname(__FILE__), "/../lib/environment")

# test/unit
require 'test/unit'


# test files
require_relative "notification"

require Environment::LIBDIR + '/config/parser'
require_relative "config_parser"
