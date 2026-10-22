# frozen_string_literal: true

# One configuration point for where the port's files live. Every shadcn script that resolves a component's Ruby, Stimulus,
# primitive or test file requires this instead of hard-coding paths, so moving the gem (e.g. to its own repository, where the
# dev kit sits under the gem) means changing these constants or setting the env vars, nothing else. An unset or empty variable
# means "use the default".
#
#   SHADCN_GEM_DIR           root of the gem; every default below derives from it   (default ".", the repository root)
#   SHADCN_RUBY_DIR          directory of the Ruby components                 (default lib/chadcn)
#   SHADCN_NAMESPACE         Ruby namespace of the components                  (default Chadcn)
#   SHADCN_CONTROLLER_DIR    directory of the Stimulus controllers             (default app/javascript/controllers/chadcn)
#   SHADCN_PROBE_DIR         directory of the dev-only controllers (parity probes, theme panel)  (default <dummy>/app/javascript/controllers/chadcn)
#   SHADCN_PRIMITIVES_DIR    directory of the shared JS primitives             (default app/javascript/chadcn/primitives)
#   SHADCN_RUBY_TEST_DIR     directory of the Ruby component tests             (default test/chadcn)
#   SHADCN_JS_TEST_DIR       directory of the browser controller tests         (default test/javascript)
#   SHADCN_DEV_DIR           the dev kit (oracle, specs, scenarios, React catalog, golden cases)     (default dev)
#   SHADCN_PORT_DIR          oracle/specs/scenarios/deviations/state                            (default <dev>/port)
#   SHADCN_CATALOG_DIR       the React oracle renderer                                          (default <dev>/react-shadcn-catalog)
#   SHADCN_DUMMY_DIR         the dummy Rails app the Phlex side is served from                  (default <dev>/dummy)
#   SHADCN_GOLDEN_DIR        the golden regression cases                                        (default <dev>/golden)
#   SHADCN_SERVERS_FILE      where servers.rb records the running dev servers                   (default <dev>/tmp/shadcn-port/servers.json)
#   SHADCN_STIMULUS_PREFIX   Stimulus identifier prefix, `chadcn` => `chadcn--dialog`  (default chadcn). The React twins of
#                            the parity probes carry the same prefix (`chadcn---probe-*`): change both together.
module ShadcnLayout
  def self.env_or(name, default)
    value = ENV.fetch(name, "")
    (value.empty? ? default : value).freeze
  end

  GEM_DIR = env_or("SHADCN_GEM_DIR", ".")

  # A path inside the gem, relative to the repository root: "lib/chadcn" when the gem is the root (not "./lib/chadcn").
  def self.in_gem(path) = (GEM_DIR == "." ? path : "#{GEM_DIR}/#{path}").freeze

  RUBY_DIR = env_or("SHADCN_RUBY_DIR", in_gem("lib/chadcn"))
  NAMESPACE = env_or("SHADCN_NAMESPACE", "Chadcn")
  CONTROLLER_DIR = env_or("SHADCN_CONTROLLER_DIR", in_gem("app/javascript/controllers/chadcn"))
  PRIMITIVES_DIR = env_or("SHADCN_PRIMITIVES_DIR", in_gem("app/javascript/chadcn/primitives"))
  RUBY_TEST_DIR = env_or("SHADCN_RUBY_TEST_DIR", in_gem("test/chadcn"))
  JS_TEST_DIR = env_or("SHADCN_JS_TEST_DIR", in_gem("test/javascript"))
  STIMULUS_PREFIX = env_or("SHADCN_STIMULUS_PREFIX", "chadcn")

  # The dev kit (not packaged). Every path is relative to the repository root, like the ones above.
  DEV_DIR = env_or("SHADCN_DEV_DIR", in_gem("dev"))
  PORT_DIR = env_or("SHADCN_PORT_DIR", "#{DEV_DIR}/port")
  ORACLE_DIR = "#{PORT_DIR}/oracle".freeze
  SPECS_DIR = "#{PORT_DIR}/specs".freeze
  SCENARIOS_DIR = "#{PORT_DIR}/scenarios".freeze
  DEVIATIONS_DIR = "#{PORT_DIR}/deviations".freeze
  STATE_FILE = "#{PORT_DIR}/state.json".freeze
  DEVIATIONS_REGISTER = "#{PORT_DIR}/DEVIATIONS.md".freeze
  CATALOG_DIR = env_or("SHADCN_CATALOG_DIR", "#{DEV_DIR}/react-shadcn-catalog")
  DUMMY_DIR = env_or("SHADCN_DUMMY_DIR", "#{DEV_DIR}/dummy")
  GOLDEN_DIR = env_or("SHADCN_GOLDEN_DIR", "#{DEV_DIR}/golden")
  # Dev-only Stimulus controllers (the `_probe_*` parity probes and the theme panel). They are served by the dummy app and must never sit in
  # CONTROLLER_DIR: that tree is packaged and pinned by every consumer.
  PROBE_DIR = env_or("SHADCN_PROBE_DIR", "#{DUMMY_DIR}/app/javascript/controllers/chadcn")
  # The theme both sides read: the gem's shipped default theme (the dummy app's config.chadcn.theme_dir, the React catalog's
  # @host-theme alias).
  THEME_DIR = in_gem("app/assets/tailwind/chadcn").freeze
  PRESETS_DIR = "#{THEME_DIR}/presets".freeze
  SERVERS_FILE = env_or("SHADCN_SERVERS_FILE", "#{DEV_DIR}/tmp/shadcn-port/servers.json")
  TMP_DIR = "tmp/shadcn-port"

  # Components whose Ruby constant is not the PascalCase of the kebab-case name (acronyms); empty today.
  CONSTANT_OVERRIDES = {}.freeze

  # `button-group` => `button_group`
  def self.ruby_name(component) = component.tr("-", "_")

  # `button-group` => `Chadcn::ButtonGroup`
  def self.root_constant(component) = "#{NAMESPACE}::#{root_class_name(component)}"

  # `button-group` => `ButtonGroup` (the class name without the namespace)
  def self.root_class_name(component) = CONSTANT_OVERRIDES.fetch(component) { component.split("-").map(&:capitalize).join }

  def self.component_files(component)
    name = ruby_name(component)
    Dir[File.join(RUBY_DIR, "#{name}.rb")] + Dir[File.join(RUBY_DIR, name, "**/*.rb")]
  end

  def self.controller_file(component) = File.join(CONTROLLER_DIR, "#{ruby_name(component)}_controller.js")

  # `dialog` => `chadcn--dialog`
  def self.identifier(component) = "#{STIMULUS_PREFIX}--#{component}"

  # `under("/tmp/work", PORT_DIR)` => `/tmp/work/<port dir>`: the same layout inside another root (a golden work dir, a rehearsal repo).
  def self.under(root, path) = File.join(root, path)

  # Every path above as a hash, for the scripts that are not Ruby (`ruby layout.rb --json`).
  def self.to_h
    constants.grep(/_(DIR|FILE|REGISTER)\z/).to_h { |name| [name.to_s, const_get(name)] }
  end
end

if $PROGRAM_NAME == __FILE__ && ARGV == ["--json"]
  require "json"
  puts JSON.generate(ShadcnLayout.to_h)
end
