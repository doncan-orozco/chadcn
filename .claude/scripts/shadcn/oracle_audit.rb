#!/usr/bin/env ruby
# frozen_string_literal: true

# Consistency audit of an extracted oracle: compares what the extractor produced (manifest) with an
# independent count taken straight from the TSX source. Catches extractor blind spots before every
# downstream gate inherits them (e.g. components declared as arrow functions).
#
#   ruby .claude/scripts/shadcn/oracle_audit.rb [--oracle <oracle dir>]
# Prints JSON { pass, scanned, findings: [{ code, component, detail }] }; exit 1 on findings.
#
# Codes: AUDIT_TIER_LIBRARY, AUDIT_CVA_COUNT, AUDIT_CVA_EMPTY, AUDIT_SLOT_MISMATCH, AUDIT_PART_COUNT, AUDIT_NO_TOKENS, AUDIT_TIER, AUDIT_NO_EXPORTS

require_relative "layout"
require "json"
require "optparse"

oracle = ShadcnLayout::ORACLE_DIR
OptionParser.new { |o| o.on("--oracle DIR") { |v| oracle = v } }.parse!

findings = []
add = ->(code, name, detail) { findings << { code: code, component: name, detail: detail } }
scanned = 0

Dir[File.join(oracle, "manifest/*.json")].sort.each do |file|
  m = JSON.parse(File.read(file))
  name = m["name"]
  src = File.read(File.join(oracle, "src/#{name}.tsx"))
  scanned += 1

  cva_src = src.scan(/=\s*cva\(/).size
  add.call("AUDIT_CVA_COUNT", name, "source has #{cva_src} cva(), manifest #{m['cva'].size}") if cva_src != m["cva"].size
  m["cva"].each { |k, c| add.call("AUDIT_CVA_EMPTY", name, "#{k} parsed no variants") if c["variants"].empty? && src[/#{Regexp.escape(k)}\s*=\s*cva\(.*?\n\)\n/m].to_s.include?("variants:") }

  slots = src.scan(/data-slot=(?:"([^"]+)"|\{"([^"]+)"\})/).flatten.compact.uniq.sort
  add.call("AUDIT_SLOT_MISMATCH", name, "source #{slots}, manifest #{m['data_slots']}") if slots != m["data_slots"]

  parts_src = src.scan(/^(?:function\s+\w+|const\s+[A-Z]\w*\s*=\s*(?:async\s*)?\()/).size
  add.call("AUDIT_PART_COUNT", name, "source declares #{parts_src} components, manifest #{m['parts'].size}") if parts_src != m["parts"].size

  add.call("AUDIT_NO_TOKENS", name, "source has className but manifest has no class tokens") if m["class_tokens"].empty? && src.include?("className")
  add.call("AUDIT_TIER", name, "tier static but uses #{m['radix_primitives'] - ['Slot']}") if m["tier"] == "static" && (m["radix_primitives"] - ["Slot"]).any?
  add.call("AUDIT_NO_EXPORTS", name, "no exports found") if m["exports"].empty?

  # Behavior that does not come from Radix (Base UI, @shadcn/react, cmdk, vaul...) must never be planned as a Radix component.
  non_radix = %w[@base-ui/react @shadcn/react cmdk sonner embla-carousel-react react-day-picker recharts input-otp react-resizable-panels vaul react-hook-form].select { |lib| src.include?("from \"#{lib}") }
  add.call("AUDIT_TIER_LIBRARY", name, "imports #{non_radix.join(', ')} but tier is #{m['tier']} (expected third_party)") if non_radix.any? && m["tier"] != "third_party"
end

puts JSON.pretty_generate(pass: findings.empty?, scanned: scanned, findings: findings)
exit(findings.empty? ? 0 : 1)
