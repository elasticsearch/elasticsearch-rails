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

require 'spec_helper'

describe Elasticsearch::Model::Response::Aggregations do

  before(:all) do
    class OriginClass
      def self.index_name;    'foo'; end
    end
  end

  after(:all) do
    remove_classes(OriginClass)
  end

  let(:response_document) do
    {
        'aggregations' => {
            'foo' => {'bar' => 10 },
            'price' => {
              'doc_count' => 123,
              'min' => { 'value' => 1.0},
              'max' => { 'value' => 99 }
            }
        }
    }
  end

  let(:search) do
    Elasticsearch::Model::Searching::SearchRequest.new(OriginClass, '*').tap do |request|
      allow(request).to receive(:execute!).and_return(response_document)
    end
  end

  let(:aggregations) do
    Elasticsearch::Model::Response::Response.new(OriginClass, search).aggregations
  end

  describe 'method delegation' do

    it 'delegates methods to the response document' do
      expect(aggregations.foo).to be_a(Hashie::Mash)
      expect(aggregations.foo.bar).to be(10)
    end
  end

  describe '#doc_count' do

    it 'returns the doc count value from the response document' do
      expect(aggregations.price.doc_count).to eq(123)
    end
  end

  describe '#min' do

    it 'returns the min value from the response document' do
      expect(aggregations.price.min.value).to eq(1)
    end
  end

  describe '#max' do

    it 'returns the max value from the response document' do
      expect(aggregations.price.max.value).to eq(99)
    end
  end

  describe '#dup' do

    it 'creates a copy of the aggregation' do
      expect(aggregations.dup).to eq(aggregations)
    end
  end
end
