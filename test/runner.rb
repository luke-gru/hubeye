#!/usr/bin/env ruby

# environment file
require File.join(File.expand_path(File.dirname(__FILE__) + '/..'), "lib/hubeye/config/environment")

# test/unit
require 'test/unit'

# test files
require_relative 'environment'
require File.join(File.expand_path(File.dirname(__FILE__) + '/..'), "lib/hubeye/notification/finder")
require_relative "notification"
require Hubeye::Environment::LIBDIR + '/hubeye/config/parser'
require_relative "config_parser"

