import DialogController from "controllers/shadcn/dialog_controller"

// Radix Dialog as shadcn Sheet. Spec: docs/shadcn-port/specs/sheet.md (Behavior). The behavior is the dialog's: this
// controller only answers to its own identifier (values data-shadcn--sheet-*, host selector) and reuses the markers the
// dialog controller reads from the parts (data-shadcn--dialog-part, data-shadcn--dialog-template).
export default class extends DialogController {
  templates() {
    return [...this.element.querySelectorAll("template[data-shadcn--dialog-template]")].filter(
      (template) => template.getAttribute("data-shadcn--dialog-template") === this.idValue && template.closest("[data-controller~='shadcn--sheet']") === this.element
    )
  }
}
