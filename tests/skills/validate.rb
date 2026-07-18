#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "pathname"
require "yaml"

ROOT = Pathname.new(File.expand_path("../..", __dir__))
EXPECTED_SKILLS = %w[nginx-cdn nginx-spa].freeze

def fail_validation(message)
  warn "skills validation: #{message}"
  exit 1
end

def load_frontmatter(path)
  content = path.read(encoding: "UTF-8")
  match = content.match(/\A---\s*\n(.*?)\n---\s*\n/m)
  fail_validation("missing YAML frontmatter in #{path.relative_path_from(ROOT)}") unless match

  data = YAML.safe_load(match[1], permitted_classes: [], permitted_symbols: [], aliases: false)
  fail_validation("frontmatter must be a mapping in #{path.relative_path_from(ROOT)}") unless data.is_a?(Hash)

  [data, content]
rescue Psych::SyntaxError => error
  fail_validation("invalid frontmatter in #{path.relative_path_from(ROOT)}: #{error.message}")
end

def validate_links(skill_root, source_file, content)
  content.scan(/\[[^\]]+\]\(([^)]+)\)/).flatten.each do |target|
    next if target.match?(%r{\A(?:https?://|#|/)})

    clean_target = target.split("#", 2).first
    resolved = source_file.dirname.join(clean_target).cleanpath
    unless resolved.to_s.start_with?("#{skill_root}/") && resolved.exist?
      fail_validation("broken relative link #{target.inspect} in #{source_file.relative_path_from(ROOT)}")
    end
  end
end

def validate_functional_evals(skill_root, name)
  path = skill_root.join("evals/evals.json")
  fail_validation("missing #{path.relative_path_from(ROOT)}") unless path.file?
  data = JSON.parse(path.read(encoding: "UTF-8"))
  fail_validation("eval skill_name mismatch for #{name}") unless data["skill_name"] == name

  evals = data["evals"]
  fail_validation("#{name} requires exactly four functional evals") unless evals.is_a?(Array) && evals.length == 4
  ids = evals.map { |item| item["id"] }
  fail_validation("#{name} eval IDs must be unique") unless ids.compact.uniq.length == evals.length

  evals.each do |item|
    %w[prompt expected_output].each do |field|
      fail_validation("#{name} eval #{item['id']} has invalid #{field}") unless item[field].is_a?(String) && !item[field].strip.empty?
    end
    files = item["files"]
    fail_validation("#{name} eval #{item['id']} files must be an array") unless files.is_a?(Array)
    assertions = item["assertions"]
    unless assertions.is_a?(Array) && !assertions.empty? && assertions.all? { |entry| entry.is_a?(String) && !entry.strip.empty? }
      fail_validation("#{name} eval #{item['id']} requires non-empty string assertions")
    end
  end
rescue JSON::ParserError => error
  fail_validation("invalid JSON in #{path.relative_path_from(ROOT)}: #{error.message}")
end

def validate_trigger_evals(skill_root, name)
  path = skill_root.join("evals/trigger-evals.json")
  fail_validation("missing #{path.relative_path_from(ROOT)}") unless path.file?
  items = JSON.parse(path.read(encoding: "UTF-8"))
  fail_validation("#{name} requires exactly 20 trigger evals") unless items.is_a?(Array) && items.length == 20
  fail_validation("#{name} trigger queries must be unique") unless items.map { |item| item["query"] }.uniq.length == 20

  counts = items.each_with_object(Hash.new(0)) do |item, result|
    result[item["should_trigger"]] += 1
  end
  fail_validation("#{name} trigger evals must contain 10 positive and 10 negative cases") unless counts == { true => 10, false => 10 }
  items.each do |item|
    unless item["query"].is_a?(String) && !item["query"].strip.empty? && [true, false].include?(item["should_trigger"])
      fail_validation("#{name} contains an invalid trigger eval")
    end
  end
rescue JSON::ParserError => error
  fail_validation("invalid JSON in #{path.relative_path_from(ROOT)}: #{error.message}")
end

EXPECTED_SKILLS.each do |name|
  skill_root = ROOT.join("skills", name)
  skill_file = skill_root.join("SKILL.md")
  fail_validation("missing #{skill_file.relative_path_from(ROOT)}") unless skill_file.file?

  metadata, content = load_frontmatter(skill_file)
  fail_validation("frontmatter name must match directory #{name}") unless metadata["name"] == name
  fail_validation("invalid skill name #{name}") unless name.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/) && name.length <= 64

  description = metadata["description"]
  unless description.is_a?(String) && description.length.between?(1, 1024)
    fail_validation("#{name} description must be 1-1024 characters")
  end
  fail_validation("#{name} must use license AGPL-3.0-only") unless metadata["license"] == "AGPL-3.0-only"
  compatibility = metadata["compatibility"]
  if !compatibility.is_a?(String) || !compatibility.length.between?(1, 500)
    fail_validation("#{name} compatibility must be 1-500 characters")
  end
  extra_metadata = metadata["metadata"]
  unless extra_metadata.is_a?(Hash) && extra_metadata.all? { |key, value| key.is_a?(String) && value.is_a?(String) }
    fail_validation("#{name} metadata must be a string-to-string mapping")
  end
  fail_validation("#{name} must not use experimental allowed-tools") if metadata.key?("allowed-tools")
  fail_validation("#{name} SKILL.md exceeds 500 lines") if content.lines.length > 500

  markdown_files = [skill_file] + skill_root.join("references").children.select { |path| path.file? && path.extname == ".md" }
  fail_validation("#{name} must contain exactly four reference Markdown files") unless markdown_files.length == 5
  markdown_files.each do |markdown_file|
    validate_links(skill_root, markdown_file, markdown_file.read(encoding: "UTF-8"))
  end
  validate_functional_evals(skill_root, name)
  validate_trigger_evals(skill_root, name)

  expected_assets = %w[Dockerfile compose.yaml kubernetes.yaml]
  actual_assets = skill_root.join("assets").children.select(&:file?).map(&:basename).map(&:to_s).sort
  fail_validation("#{name} assets must be exactly #{expected_assets.join(', ')}") unless actual_assets == expected_assets.sort
  %w[compose.yaml kubernetes.yaml].each do |asset_name|
    asset_path = skill_root.join("assets", asset_name)
    stream = Psych.parse_stream(asset_path.read(encoding: "UTF-8"))
    fail_validation("#{asset_path.relative_path_from(ROOT)} must contain YAML documents") if stream.children.empty?
  rescue Psych::SyntaxError => error
    fail_validation("invalid YAML in #{asset_path.relative_path_from(ROOT)}: #{error.message}")
  end
  dockerfile = skill_root.join("assets/Dockerfile").read(encoding: "UTF-8")
  fail_validation("#{name} asset Dockerfile must not use latest") if dockerfile.match?(/:latest(?:\s|$)/)
  expected_image = metadata.fetch("metadata").fetch("image")
  fail_validation("#{name} asset Dockerfile must pin #{expected_image}") unless dockerfile.include?("FROM #{expected_image}")

  scripts = skill_root.join("scripts").children.select(&:file?)
  fail_validation("#{name} must bundle a verification script") if scripts.empty?
  scripts.each do |script|
    fail_validation("#{script.relative_path_from(ROOT)} is not executable") unless script.executable?
    fail_validation("#{script.relative_path_from(ROOT)} is not valid POSIX shell") unless system("sh", "-n", script.to_s)
  end
end

catalog = YAML.safe_load(
  ROOT.join("catalog/images.yaml").read(encoding: "UTF-8"),
  permitted_classes: [],
  permitted_symbols: [],
  aliases: true
)
targets = catalog.fetch("active_images").each_with_object([]) do |image, result|
  result << image["consumer_skill_target"] if image["consumer_skill_target"]
end
EXPECTED_SKILLS.each do |name|
  expected_target = "skills/#{name}"
  fail_validation("catalog does not target #{expected_target}") unless targets.include?(expected_target)
end

puts "Consumer skill validation passed"
