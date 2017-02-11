require 'ansi'
require 'sqlite3'
require 'active_record'
require 'elasticsearch/model'

ActiveRecord::Base.logger = ActiveSupport::Logger.new(STDOUT)
ActiveRecord::Base.establish_connection( adapter: 'sqlite3', database: ":memory:" )

ActiveRecord::Schema.define(version: 1) do
  create_table :articles do |t|
    t.string :title
    t.date   :published_at
    t.timestamps
  end
end

class Article < ActiveRecord::Base
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks

  article_es_settings = {
    index: {
      analysis: {
        filter: {
          autocomplete_filter: {
            type: "edge_ngram",
            min_gram: 1,
            max_gram: 20
          }
        },
        analyzer:{
          autocomplete: {
            type: "custom",
            tokenizer: "standard",
            filter: ["lowercase", "autocomplete_filter"]
          }
        }
      }
    }
  }

  settings article_es_settings do
    mapping do
      indexes :title
      indexes :suggestable_title, type: 'string', analyzer: 'autocomplete'
    end
  end

  def as_indexed_json(options={})
    as_json.merge(suggestable_title: title)
  end
end

Article.__elasticsearch__.client = Elasticsearch::Client.new log: true

# Create index

Article.__elasticsearch__.create_index! force: true

# Store data

Article.delete_all
Article.create title: 'Foo'
Article.create title: 'Bar'
Article.create title: 'Foo Foo'
Article.__elasticsearch__.refresh_index!

# Search and suggest
fulltext_search_response = Article.search(query: { match: { title: 'foo'} } )

puts "Article search:".ansi(:bold),
     fulltext_search_response.to_a.map { |d| "Title: #{d.title}" }.inspect.ansi(:bold, :yellow)

fulltext_search_response_2 = Article.search(query: { match: { title: 'fo'} } )

puts "Article search:".ansi(:bold),
     fulltext_search_response_2.to_a.map { |d| "Title: #{d.title}" }.inspect.ansi(:bold, :red)

autocomplete_search_response = Article.search(query: { match: { suggestable_title: { query: 'fo', analyzer: 'standard'} } } )

puts "Article suggest:".ansi(:bold),
     autocomplete_search_response.to_a.map { |d| "Title: #{d.suggestable_title}" }.inspect.ansi(:bold, :green)


# Elasticsearch will index :title with standard analyzer as fulltext search:
#
#   * foo
#   * bar
#
# but field :suggestable_title is indexed with or autocomplete
# edge-ngram analyzer so that string is reverse-indexed as:
#
#   * f
#   * fo
#   * foo
#   * b
#   * ba
#   * bar

require 'pry'; binding.pry;
