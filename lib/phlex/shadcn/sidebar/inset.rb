# frozen_string_literal: true

# shadcn SidebarInset: the page content next to the sidebar (a `main`; no data-sidebar).
class Phlex::Shadcn::Sidebar::Inset < Phlex::Shadcn::Base
  CLASSES = [
    "relative flex w-full flex-1 flex-col bg-background",
    "md:peer-data-[variant=inset]:m-2 md:peer-data-[variant=inset]:ml-0 md:peer-data-[variant=inset]:rounded-xl md:peer-data-[variant=inset]:shadow-sm md:peer-data-[variant=inset]:peer-data-[state=collapsed]:ml-2"
  ].freeze

  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  def view_template(&)
    main(**merge_attrs({ class: cn(CLASSES), data: { slot: "sidebar-inset" } }, @attrs), &)
  end
end
