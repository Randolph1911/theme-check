# frozen_string_literal: true
require 'yaml'

module LiquidAPI
  module Filters
    extend self

    UNDOCUMENTED_FILTERS = [
      "customer_logout_link",
      "customer_register_link",
      "format_code",
      "handle",
      "product_img_url",
      "t",
      "translate",
    ]

    def labels
      @labels ||= begin
        label_set = Set.new
        filters = YAML.load(File.read('data/liquid_api/filters.yml'))
        filters.each do |group|
          group['items'].each do |item|
            label_set << item['label']
          end
        end

        label_set.to_a + UNDOCUMENTED_FILTERS
      end
    end
  end
end