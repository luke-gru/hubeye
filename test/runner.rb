#!/usr/bin/env ruby

# environment file
require File.join(File.expand_path(File.dirname(__FILE__) + '/..'), "lib/environment")

# test/unit
require 'test/unit'

# test files
require_relative 'environment'
require File.join(File.expand_path(File.dirname(__FILE__) + '/..'), "lib/notification/notification")
require_relative "notification"
require Environment::LIBDIR + '/config/parser'
require_relative "config_parser"

