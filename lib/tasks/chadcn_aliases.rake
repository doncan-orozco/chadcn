# frozen_string_literal: true

# Short aliases `theme:list|use|import|check` of the chadcn:theme:* tasks, unless the app turns them off with
# `config.chadcn.theme_task_aliases = false` (needed while it defines its own theme:* tasks: Rake would run both bodies, and
# `theme:import[-]` would read stdin twice).
if Rails.application.config.chadcn.theme_task_aliases
  namespace :theme do
    {
      list: nil, check: nil, use: :name, import: :source
    }.each do |name, argument|
      target = "chadcn:theme:#{name}"
      desc "Alias of #{target}"
      task name, (argument ? [ argument ] : []) => :environment do |_task, args|
        Rake::Task[target].reenable
        Rake::Task[target].invoke(*(argument ? [ args[argument] ].compact : []))
      end
    end
  end
end
