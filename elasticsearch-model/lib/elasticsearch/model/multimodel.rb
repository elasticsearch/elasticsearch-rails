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
    # Keeps a global registry of index to class mappings
    class Registry
      def initialize
        @models = []
        @indexes = {}
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
        __instance.models
      end

      def self.indexes
        __instance.indexes
      end

      def self.add_index(index, model)
        __instance.add_index(index, model)
      end

      # Adds a model to the registry
      #
      def add(klass)
        # Detect already loaded models and ensure that a duplicate is not stored
        if i = @models.index{ |_class| _class.name == klass.name }
          @models[i] = klass
          # clear the cached index map (autoloading in development causes this)
          @indexes.clear
        else
          @models << klass
        end
      end

      def add_index(index, model)
        @indexes[index] = model
      end

      # Returns a copy of the registered models
      #
      def models
        @models.dup
      end

      def indexes
        @indexes.dup
      end

      ##
      # Find the model matching the given index and document type from a search hit
      # Cache the index->model mapping for performance
      # Clear the index cache when models are reloaded
      def self.lookup(index, type=nil)
        if Registry.indexes.has_key?(index)
          # Cache hit
          Registry.indexes[index]
        else
          # Cache bust
          model = if type.nil? or type == "_doc"
            # lookup strictly by index for generic document types
            Registry.all.detect{|m| m.index_name == index}
          else
            # lookup using index and type
            Registry.all.detect{|m| m.index_name == index and model.document_type == type}
          end
          # cache the index to model mapping
          Registry.add_index(index, model)
          model
        end
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
