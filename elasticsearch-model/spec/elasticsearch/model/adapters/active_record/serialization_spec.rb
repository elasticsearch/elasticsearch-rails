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

describe 'Elasticsearch::Model::Adapter::ActiveRecord Serialization' do

  before(:all) do
    ActiveRecord::Schema.define(:version => 1) do
      create_table ArticleWithCustomSerialization.table_name do |t|
        t.string   :title
        t.string   :status
      end
    end

    ArticleWithCustomSerialization.delete_all
    ArticleWithCustomSerialization.__elasticsearch__.create_index!(force: true)
  end

  context 'when the model has a custom serialization defined' do

    before do
      ArticleWithCustomSerialization.create!(title: 'Test', status: 'green')
      ArticleWithCustomSerialization.__elasticsearch__.refresh_index!
    end

    context 'when a document is indexed' do

      let(:search_result) do
        ArticleWithCustomSerialization.__elasticsearch__.client.get(index: 'article_with_custom_serializations',
                                                                    type:  '_doc',
                                                                    id:    '1')
      end

      it 'applies the serialization when indexing' do
        expect(search_result['_source']).to eq('title' => 'Test')
      end
    end

    context 'when a document is updated' do
      before do
        article.update_attribute(:title, 'UPDATED')
        article.update_attribute(:status, 'yellow')

        ArticleWithCustomSerialization.__elasticsearch__.refresh_index!
      end

      let!(:article) do
        art = ArticleWithCustomSerialization.create!(title: 'Test', status: 'red')
        ArticleWithCustomSerialization.__elasticsearch__.refresh_index!
        art
      end

      let(:search_result) do
        ArticleWithCustomSerialization.__elasticsearch__.client.get(index: 'article_with_custom_serializations',
                                                                    type:  '_doc',
                                                                    id:    article.id)
      end

      it 'applies the serialization when updating' do
        expect(search_result['_source']).to eq('title' => 'UPDATED')
      end
    end
  end
end
