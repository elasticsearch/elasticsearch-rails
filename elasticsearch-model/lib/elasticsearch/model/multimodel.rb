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
  module Model
    # Keeps a global registry of classes that include `Elasticsearch::Model`
    #
    class Registry
      def initialize
        @models = []
      end

      # Returns the unique instance of the registry (Singleton)
      #
      # @api private
      #
      def self.__instance
        @instance ||= new
      end

      # Adds a model to the registry
      #
      def self.add(klass)
        __instance.add(klass)
      end

      # Returns an Array of registered models
      #
      def self.all
        __instance.models.sort_by(&:name)
      end

      # Adds a model to the registry
      #
      def add(klass)
        @models << klass
      end

      # Returns a copy of the registered models
      #
      def models
        @models.dup
      end
    end

    # Wraps a collection of models when querying multiple indices
    #
    # @see Elasticsearch::Model.search
    #
    class Multimodel
      attr_reader :models

      # @param models [Class] The list of models across which the search will be performed
      #
      def initialize(*models)
        @models = models.flatten
        @models = Model::Registry.all if @models.empty?
      end

      # Get an Array of index names used for retrieving documents when doing a search across multiple models
      #
      # @return [Array] the list of index names used for retrieving documents
      #
      def index_name
        models.map { |m| m.index_name }
      end

      # Get the client common for all models
      #
      # @return Elastic::Transport::Client
      #
      def client
        Elasticsearch::Model.client
      end
    end
  end
end
