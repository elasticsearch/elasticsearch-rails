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
require 'elasticsearch/rails/instrumentation/log_subscriber'

describe Elasticsearch::Rails::Instrumentation::LogSubscriber do
  subject(:instance) { described_class.new }

  let(:logger) { instance_double(Logger) }

  before do
    allow(instance).to receive(:logger) { logger }
  end

  describe "#search" do
    subject { instance.search(event) }

    let(:event) { double("search.elasticsearch", duration: 1.2345, payload: { name: "execute", search: { query: { match_all: {}}}}) }

    it "logs the event" do
      expect(instance).to receive(:color).with(" execute (1.2ms)", described_class::GREEN, { bold: true }).and_call_original
      expect(logger).to receive(:debug?) { true }
      expect(logger).to receive(:debug).with("  \e[1m\e[32m execute (1.2ms)\e[0m \e[2m{query: {match_all: {}}}\e[0m")
      subject
    end

    context "when Rails version is older" do
      let(:rails_version) { "7.0.0" }

      before do
        allow(::Rails).to receive(:gem_version) { Gem::Version.new(rails_version) }
      end

      it "logs the event" do
        expect(instance).to receive(:color).with(" execute (1.2ms)", described_class::GREEN, true).and_call_original
        expect(logger).to receive(:debug?) { true }
        expect(logger).to receive(:debug).with("  \e[1m\e[32m execute (1.2ms)\e[0m \e[2m{query: {match_all: {}}}\e[0m")
        subject
      end
    end
  end
end
