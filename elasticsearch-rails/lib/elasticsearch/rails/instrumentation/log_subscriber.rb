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

module Elasticsearch
  module Rails
    module Instrumentation

      # A log subscriber to attach to Elasticsearch related events
      #
      # @see https://github.com/rails/rails/blob/master/activerecord/lib/active_record/log_subscriber.rb
      #
      class LogSubscriber < ActiveSupport::LogSubscriber
        def self.runtime=(value)
          Thread.current["elasticsearch_runtime"] = value
        end

        def self.runtime
          Thread.current["elasticsearch_runtime"] ||= 0
        end

        def self.reset_runtime
          rt, self.runtime = runtime, 0
          rt
        end

        # Intercept `search.elasticsearch` events, and display them in the Rails log
        #
        def search(event)
          self.class.runtime += event.duration
          return unless logger.debug?

          payload = event.payload
          name    = "#{payload[:klass]} #{payload[:name]} (#{event.duration.round(1)}ms)"
          search  = payload[:search].inspect.gsub(/:(\w+)=>/, '\1: ')
          debug %Q|  #{color(name, GREEN, color_option(true))} #{colorize_logging ? "\e[2m#{search}\e[0m" : search}|
        end

        private

        def color_option(bold_value)
          new_color_syntax? ? { bold: bold_value } : bold_value
        end

        def new_color_syntax?
          return @new_color_syntax if defined?(@new_color_syntax)

          @new_color_syntax = ::Rails.respond_to?(:gem_version) && ::Rails.gem_version >= Gem::Version.new('7.1')
        end
      end

    end
  end
end

Elasticsearch::Rails::Instrumentation::LogSubscriber.attach_to :elasticsearch
