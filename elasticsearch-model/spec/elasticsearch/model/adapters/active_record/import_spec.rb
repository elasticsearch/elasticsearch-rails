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

describe 'Elasticsearch::Model::Adapter::ActiveRecord Importing' do
  before(:all) do
    ActiveRecord::Schema.define(:version => 1) do
      create_table :import_articles do |t|
        t.string   :title
        t.integer  :views
        t.string   :numeric # For the sake of invalid data sent to Elasticsearch
        t.datetime :created_at, :default => 'NOW()'
      end
    end

    ImportArticle.delete_all
    ImportArticle.__elasticsearch__.client.cluster.health(wait_for_status: 'yellow')
  end

  before do
    ImportArticle.__elasticsearch__.create_index!
  end

  after do
    clear_indices(ImportArticle)
    clear_tables(ImportArticle)
  end

  describe '#import' do
    context 'when no search criteria is specified' do
      before do
        10.times { |i| ImportArticle.create! title: 'Test', views: i.to_s }
        ImportArticle.import
        ImportArticle.__elasticsearch__.refresh_index!
      end

      it 'imports all documents' do
        expect(ImportArticle.search('*').results.total).to eq(10)
      end

      it "does not pollute the model's namespace" do
        expect(ImportArticle.methods).not_to include(:__transform)
      end
    end

    context 'when batch size is specified' do
      before do
        10.times { |i| ImportArticle.create! title: 'Test', views: "#{i}" }
      end

      let!(:batch_count) do
        batches = 0
        errors  = ImportArticle.import(batch_size: 5) do |response|
          batches += 1
        end
        ImportArticle.__elasticsearch__.refresh_index!
        batches
      end

      it 'imports using the batch size' do
        expect(batch_count).to eq(2)
      end

      it 'imports all the documents' do
        expect(ImportArticle.search('*').results.total).to eq(10)
      end
    end

    context 'when a scope is specified' do
      before do
        10.times { |i| ImportArticle.create! title: 'Test', views: "#{i}" }
        ImportArticle.import(scope: 'popular', force: true)
        ImportArticle.__elasticsearch__.refresh_index!
      end

      it 'applies the scope' do
        expect(ImportArticle.search('*').results.total).to eq(5)
      end
    end

    context 'when a query is specified' do
      before do
        10.times { |i| ImportArticle.create! title: 'Test', views: "#{i}" }
        ImportArticle.import(query: -> { where('views >= 3') })
        ImportArticle.__elasticsearch__.refresh_index!
      end

      it 'applies the query' do
        expect(ImportArticle.search('*').results.total).to eq(7)
      end
    end

    context 'when there are invalid documents' do
      let!(:result) do
        10.times { |i| ImportArticle.create! title: 'Test', views: "#{i}" }
        new_article
        batches = 0
        errors  = ImportArticle.__elasticsearch__.import(batch_size: 5) do |response|
          batches += 1
        end
        ImportArticle.__elasticsearch__.refresh_index!
        { batch_size: batches, errors: errors}
      end

      let(:new_article) do
        ImportArticle.create!(title: "Test INVALID", numeric: "INVALID")
      end

      it 'does not import them' do
        expect(ImportArticle.search('*').results.total).to eq(10)
        expect(result[:batch_size]).to eq(3)
        expect(result[:errors]).to eq(1)
      end
    end

    context 'when a transform proc is specified' do
      before do
        10.times { |i| ImportArticle.create! title: 'Test', views: "#{i}" }
        ImportArticle.import( transform: ->(a) {{ index: { data: { name: a.title, foo: 'BAR' } }}} )
        ImportArticle.__elasticsearch__.refresh_index!
      end

      it 'transforms the documents' do
        expect(ImportArticle.search('*').results.first._source.keys).to include('name')
        expect(ImportArticle.search('*').results.first._source.keys).to include('foo')
      end

      it 'imports all documents' do
        expect(ImportArticle.search('test').results.total).to eq(10)
        expect(ImportArticle.search('bar').results.total).to eq(10)
      end
    end

    context 'when the model has a default scope' do
      around(:all) do |example|
        10.times { |i| ImportArticle.create! title: 'Test', views: "#{i}" }
        ImportArticle.instance_eval { default_scope { where('views > 3') } }
        example.run
        ImportArticle.default_scopes.pop
      end

      before do
        ImportArticle.__elasticsearch__.import
        ImportArticle.__elasticsearch__.refresh_index!
      end

      it 'uses the default scope' do
        expect(ImportArticle.search('*').results.total).to eq(6)
      end
    end

    context 'when there is a default scope and a query specified' do
      around(:all) do |example|
        10.times { |i| ImportArticle.create! title: 'Test', views: "#{i}" }
        ImportArticle.instance_eval { default_scope { where('views > 3') } }
        example.run
        ImportArticle.default_scopes.pop
      end

      before do
        ImportArticle.import(query: -> { where('views <= 4') })
        ImportArticle.__elasticsearch__.refresh_index!
      end

      it 'combines the query and the default scope' do
        expect(ImportArticle.search('*').results.total).to eq(1)
      end
    end

    context 'when the batch is empty' do
      before do
        ImportArticle.delete_all
        ImportArticle.import
        ImportArticle.__elasticsearch__.refresh_index!
      end

      it 'does not make any requests to create documents' do
        expect(ImportArticle.search('*').results.total).to eq(0)
      end
    end
  end
end
