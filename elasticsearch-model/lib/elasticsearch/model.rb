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

require 'hashie/mash'

require 'active_support/core_ext/module/delegation'

require 'elasticsearch'

require 'elasticsearch/model/version'

require 'elasticsearch/model/hash_wrapper'
require 'elasticsearch/model/client'

require 'elasticsearch/model/multimodel'

require 'elasticsearch/model/adapter'
require 'elasticsearch/model/adapters/default'
require 'elasticsearch/model/adapters/active_record'
require 'elasticsearch/model/adapters/mongoid'
require 'elasticsearch/model/adapters/multiple'

require 'elasticsearch/model/importing'
require 'elasticsearch/model/indexing'
require 'elasticsearch/model/naming'
require 'elasticsearch/model/serializing'
require 'elasticsearch/model/searching'
require 'elasticsearch/model/callbacks'

require 'elasticsearch/model/proxy'

require 'elasticsearch/model/response'
require 'elasticsearch/model/response/base'
require 'elasticsearch/model/response/result'
require 'elasticsearch/model/response/results'
require 'elasticsearch/model/response/records'
require 'elasticsearch/model/response/pagination'
require 'elasticsearch/model/response/aggregations'
require 'elasticsearch/model/response/suggestions'

require 'elasticsearch/model/ext/active_record'

case
when defined?(::Kaminari)
  Elasticsearch::Model::Response::Response.__send__ :include, Elasticsearch::Model::Response::Pagination::Kaminari
when defined?(::WillPaginate)
  Elasticsearch::Model::Response::Response.__send__ :include, Elasticsearch::Model::Response::Pagination::WillPaginate
end

module Elasticsearch

  # Elasticsearch integration for Ruby models
  # =========================================
  #
  # `Elasticsearch::Model` contains modules for integrating the Elasticsearch search and analytical engine
  # with ActiveModel-based classes, or models, for the Ruby programming language.
  #
  # It facilitates importing your data into an index, automatically updating it when a record changes,
  # searching the specific index, setting up the index mapping or the model JSON serialization.
  #
  # When the `Elasticsearch::Model` module is included in your class, it automatically extends it
  # with the functionality; see {Elasticsearch::Model.included}. Most methods are available via
  # the `__elasticsearch__` class and instance method proxies.
  #
  # It is possible to include/extend the model with the corresponding
  # modules directly, if that is desired:
  #
  #     MyModel.__send__ :extend,  Elasticsearch::Model::Client::ClassMethods
  #     MyModel.__send__ :include, Elasticsearch::Model::Client::InstanceMethods
  #     MyModel.__send__ :extend,  Elasticsearch::Model::Searching::ClassMethods
  #     # ...
  #
  module Model
    METHODS = [:search, :mapping, :mappings, :settings, :index_name, :document_type, :import]

    # Adds the `Elasticsearch::Model` functionality to the including class.
    #
    # * Creates the `__elasticsearch__` class and instance method. These methods return a proxy object with
    #   other common methods defined on them.
    # * The module includes other modules with further functionality.
    # * Sets up delegation for common methods such as `import` and `search`.
    #
    # @example Include the module in the `Article` model definition
    #
    #     class Article < ActiveRecord::Base
    #       include Elasticsearch::Model
    #     end
    #
    # @example Inject the module into the `Article` model during run time
    #
    #     Article.__send__ :include, Elasticsearch::Model
    #
    #
    def self.included(base)
      base.class_eval do
        include Elasticsearch::Model::Proxy

        # Delegate common methods to the `__elasticsearch__` ClassMethodsProxy, unless they are defined already
        class << self
          METHODS.each do |method|
            delegate method, to: :__elasticsearch__ unless self.public_instance_methods.include?(method)
          end

          def inherited(subclass)
            super
            Registry.add(subclass) if subclass.is_a?(Class)
          end
        end
      end

      # Add to the model to the registry if it's a class (and not in intermediate module)
      Registry.add(base) if base.is_a?(Class)
    end

    module ClassMethods
      # Get the client common for all models
      #
      # @example Get the client
      #
      #     Elasticsearch::Model.client
      #     => #<Elasticsearch::Client:0x007f96a7d0d000... >
      #
      def client
        @client ||= Elasticsearch::Client.new
      end

      # Set the client for all models
      #
      # @example Configure (set) the client for all models
      #
      #     Elasticsearch::Model.client = Elasticsearch::Client.new host: 'http://localhost:9200', tracer: true
      #     => #<Elasticsearch::Client:0x007f96a6dd0d80... >
      #
      # @note You have to set the client before you call Elasticsearch methods on the model,
      #       or set it directly on the model; see {Elasticsearch::Model::Client::ClassMethods#client}
      #
      def client=(client)
        @client = client
      end

      # Search across multiple models
      #
      # By default, all models which include the `Elasticsearch::Model` module are searched
      #
      # @param query_or_payload [String,Hash,Object] The search request definition
      #                                              (string, JSON, Hash, or object responding to `to_hash`)
      # @param models [Array] The Array of Model objects to search
      # @param options [Hash] Optional parameters to be passed to the Elasticsearch client
      #
      # @return [Elasticsearch::Model::Response::Response]
      #
      # @example Search across specific models
      #
      #     Elasticsearch::Model.search('foo', [Author, Article])
      #
      # @example Search across all models which include the `Elasticsearch::Model` module
      #
      #     Elasticsearch::Model.search('foo')
      #
      def search(query_or_payload, models=[], options={})
        models = Multimodel.new(models)
        request = Searching::SearchRequest.new(models, query_or_payload, options)
        Response::Response.new(models, request)
      end

      # Access the module settings
      #
      def settings
        @settings ||= {}
      end
    end
    extend ClassMethods

    class NotImplemented < NoMethodError; end
  end
end
