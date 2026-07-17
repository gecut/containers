#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"

root = File.expand_path("../..", __dir__)
catalog = YAML.safe_load(
  File.read(File.join(root, "catalog/images.yaml")),
  permitted_classes: [],
  permitted_symbols: [],
  aliases: true
)
images = catalog.fetch("active_images")

raise "expected seven active images" unless images.length == 7

by_id = images.to_h { |image| [image.fetch("id"), image] }
expected_parents = {
  "nginx-base" => nil,
  "nginx-core" => "nginx-base",
  "nginx-cdn" => "nginx-core",
  "nginx-spa" => "nginx-cdn"
}

expected_parents.each do |id, parent|
  image = by_id.fetch(id)
  raise "wrong parent for #{id}" unless image["parent"] == parent

  %w[source_context dockerfile documentation_target].each do |field|
    path = File.join(root, image.fetch(field))
    raise "missing #{field} for #{id}: #{path}" unless File.exist?(path)
  end
end

expected_versions = {
  "nginx-base" => "2.0.0",
  "nginx-core" => "2.0.0",
  "nginx-cdn" => "2.0.0",
  "nginx-spa" => "1.0.0"
}

expected_versions.each do |id, version|
  dockerfile = File.read(File.join(root, by_id.fetch(id).fetch("dockerfile")))
  raise "wrong BUILD_VERSION for #{id}" unless dockerfile.match?(/^ARG BUILD_VERSION=#{Regexp.escape(version)}$/)
end

architecture = File.read(File.join(root, "docs/architecture/image-catalog.md"))
raise "architecture graph does not contain SPA" unless architecture.include?("nginx-base -> nginx-core -> nginx-cdn -> nginx-spa")

puts "NGINX catalog contract passed"
