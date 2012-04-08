#!/usr/bin/env ruby

require File.expand_path('../test_helper', __FILE__)

# test files
require File.expand_path('../environment', __FILE__)
require File.join(File.expand_path(File.dirname(__FILE__) + '/..'), "lib/hubeye/notifiable/notification")
require File.expand_path('../notification', __FILE__)
require File.join(Hubeye::Environment::LIBDIR, '/hubeye/config/parser')
require File.expand_path('../config_parser', __FILE__)
