# Licensed to Elasticsearch B.V. under one or more contributor
# license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright
# ownership. Elasticsearch B.V. licenses this file to you under
# the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

require 'pry-nav'
require 'active_record'
require 'elasticsearch/model'
require 'elasticsearch/rails'
require 'rails/railtie'
require 'rails/version'
require 'elasticsearch/rails/instrumentation'


unless defined?(ELASTICSEARCH_URL)
  ELASTICSEARCH_URL = ENV['ELASTICSEARCH_URL'] || "localhost:#{(ENV['TEST_CLUSTER_PORT'] || 9200)}"
end

RSpec.configure do |config|
  config.formatter = 'documentation'
  config.color = true

  config.before(:suite) do
    require 'ansi'
    tracer = ::Logger.new(STDERR)
    tracer.formatter = lambda { |s, d, p, m| "#{m.gsub(/^.*$/) { |n| '   ' + n }.ansi(:faint)}\n" }
    Elasticsearch::Model.client = Elasticsearch::Client.new host: ELASTICSEARCH_URL,
                                                            tracer: (ENV['QUIET'] ? nil : tracer)
    puts "Elasticsearch Version: #{Elasticsearch::Model.client.info['version']}"

    unless ActiveRecord::Base.connected?
      ActiveRecord::Base.establish_connection( :adapter => 'sqlite3', :database => ":memory:" )
    end

    if ::ActiveRecord::Base.respond_to?(:raise_in_transactional_callbacks) && ::ActiveRecord::VERSION::MAJOR.to_s < '5'
      ::ActiveRecord::Base.raise_in_transactional_callbacks = true
    end
  end
end

# Remove all classes.
#
# @param [ Array<Class> ] classes The list of classes to remove.
#
# @return [ true ]
#
# @since 6.0.1
def remove_classes(*classes)
  classes.each do |_class|
    Object.send(:remove_const, _class.name.to_sym) if defined?(_class)
  end and true
end
