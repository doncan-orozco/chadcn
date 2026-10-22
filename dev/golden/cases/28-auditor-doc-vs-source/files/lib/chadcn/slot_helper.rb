# frozen_string_literal: true

# Seeded: faithful to the (wrong) project doc, not to the real Radix source. The unit test below locks it in.
class Chadcn::SlotHelper < Components::Base
  # Radix Slot merge, as documented: class is conflict-resolved with tailwind-merge.
  def merge_slot(slot, child)
    merged = slot.merge(child)
    merged[:class] = cn(slot[:class], child[:class])
    merged
  end
end

# test/chadcn/slot_helper_test.rb (the test asserts the documented behavior)
#   assert_equal "rounded-full px-4", helper.merge_slot({ class: "rounded-md px-2" }, { class: "rounded-full px-4" })[:class]
