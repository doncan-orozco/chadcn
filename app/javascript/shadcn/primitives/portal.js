// Port of @radix-ui/react-portal: the element lives in `container` (default: body) while portaled and goes back
// to its original position on release. Known divergences: none.
export function portal(el, container = document.body) {
  const placeholder = document.createComment("portal")
  el.before(placeholder)
  container.append(el)

  return function release() {
    placeholder.replaceWith(el)
  }
}
