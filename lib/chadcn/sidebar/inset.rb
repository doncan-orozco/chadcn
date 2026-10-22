# frozen_string_literal: true

# shadcn SidebarInset: the page content next to the sidebar (a `main`; no data-sidebar).
#
# Rendered next to a {Chadcn::Sidebar} inside the provider; also available as `sidebar.inset`.
#
# @see Chadcn::Sidebar
class Chadcn::Sidebar::Inset < Chadcn::Base
  # Tailwind classes of the `main` (verbatim from shadcn/ui).
  #
  # @api private
  CLASSES = [
    "relative flex w-full flex-1 flex-col bg-background",
    "md:peer-data-[variant=inset]:m-2 md:peer-data-[variant=inset]:ml-0 md:peer-data-[variant=inset]:rounded-xl md:peer-data-[variant=inset]:shadow-sm md:peer-data-[variant=inset]:peer-data-[state=collapsed]:ml-2"
  ].freeze

  # @param attrs [Hash] HTML attributes for the element; `class:` is tailwind-merged over the defaults, `data:` and `aria:`
  #   are deep-merged (caller wins).
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # Renders the `main` and yields the block as its content.
  #
  # @yield the content of the element
  # @return [void]
  def view_template(&)
    main(**merge_attrs({ class: cn(CLASSES), data: { slot: "sidebar-inset" } }, @attrs), &)
  end
end
