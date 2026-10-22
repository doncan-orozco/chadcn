// Toast store + stack: the behavior of sonner 2.0.7 (the library shadcn's Toaster wraps) without the library or React.
// Stands in for: `sonner` (toast() store, Toaster state, Toast stacking/timers/swipe). Source read: sonner/dist/index.mjs.
// The stylesheet that turns the data-* attributes below into the stacked look is app/assets/tailwind/chadcn/sonner.css.
// Known divergences (recorded in dev/port/deviations/sonner.json): no React elements (`toast.custom` takes a DOM node or a function
// returning one), no `useSonner` hook, an `error` toast is also announced through an assertive live region.
//
//   import { toast, ToastStack } from "chadcn/primitives/toast_stack"
//   toast.success("Saved", { description: "All changes stored", action: { label: "Undo", onClick() {} } })
//   const stack = new ToastStack(sectionElement, { position: "bottom-right", iconFor }); stack.connect(); ... stack.disconnect()

// Visible toasts amount, viewport padding, default lifetime (ms), width, gap, swipe threshold, exit animation duration (sonner constants).
const VISIBLE_TOASTS_AMOUNT = 3
const VIEWPORT_OFFSET = "24px"
const MOBILE_VIEWPORT_OFFSET = "16px"
const TOAST_LIFETIME = 4000
const TOAST_WIDTH = 356
const GAP = 14
const SWIPE_THRESHOLD = 45
const TIME_BEFORE_UNMOUNT = 200
const SIDES = ["top", "right", "bottom", "left"]

let toastsCounter = 1

/**
 * The toast store: every `toast()` call goes through it and every connected stack subscribes to it.
 * @private
 */
class Store {
  constructor() {
    this.subscribers = []
    this.toasts = []
    this.dismissedToasts = new Set()
  }

  subscribe = (subscriber) => {
    this.subscribers.push(subscriber)
    return () => {
      const index = this.subscribers.indexOf(subscriber)
      if (index !== -1) this.subscribers.splice(index, 1)
    }
  }

  publish = (data) => {
    this.subscribers.slice().forEach((subscriber) => subscriber(data))
  }

  addToast = (data) => {
    this.publish(data)
    this.toasts = [...this.toasts, data]
  }

  create = (data) => {
    const { message, ...rest } = data
    const id = typeof data?.id === "number" || data?.id?.length > 0 ? data.id : toastsCounter++
    const alreadyExists = this.toasts.find((toast) => toast.id === id)
    const dismissible = data.dismissible === undefined ? true : data.dismissible
    if (this.dismissedToasts.has(id)) this.dismissedToasts.delete(id)

    if (alreadyExists) {
      this.toasts = this.toasts.map((toast) => {
        if (toast.id !== id) return toast
        this.publish({ ...toast, ...data, id, title: message })
        return { ...toast, ...data, id, dismissible, title: message }
      })
    } else {
      this.addToast({ title: message, ...rest, dismissible, id })
    }
    return id
  }

  dismiss = (id) => {
    if (id) {
      this.dismissedToasts.add(id)
      requestAnimationFrame(() => this.subscribers.slice().forEach((subscriber) => subscriber({ id, dismiss: true })))
    } else {
      this.toasts.forEach((toast) => this.subscribers.slice().forEach((subscriber) => subscriber({ id: toast.id, dismiss: true })))
    }
    return id
  }

  message = (message, data) => this.create({ ...data, message })
  error = (message, data) => this.create({ ...data, message, type: "error" })
  success = (message, data) => this.create({ ...data, type: "success", message })
  info = (message, data) => this.create({ ...data, type: "info", message })
  warning = (message, data) => this.create({ ...data, type: "warning", message })
  loading = (message, data) => this.create({ ...data, type: "loading", message })

  custom = (content, data) => {
    const id = data?.id || toastsCounter++
    this.create({ jsx: typeof content === "function" ? content(id) : content, id, ...data })
    return id
  }

  promise = (promise, data) => {
    if (!data) return undefined
    let id
    if (data.loading !== undefined) {
      id = this.create({ ...data, promise, type: "loading", message: data.loading, description: typeof data.description !== "function" ? data.description : undefined })
    }
    const p = Promise.resolve(typeof promise === "function" ? promise() : promise)
    let shouldDismiss = id !== undefined
    let result
    const resolveSettings = async (source, argument) => {
      const settings = typeof source === "function" ? await source(argument) : source
      const description = typeof data.description === "function" ? await data.description(argument) : data.description
      const extended = typeof settings === "object" && settings !== null && !(settings instanceof Node)
      return { description, ...(extended ? settings : { message: settings }) }
    }
    const original = p
      .then(async (response) => {
        result = ["resolve", response]
        if (response instanceof Node) {
          shouldDismiss = false
          this.create({ id, type: "default", message: response })
        } else if (isHttpResponse(response) && !response.ok) {
          shouldDismiss = false
          this.create({ id, type: "error", ...(await resolveSettings(data.error, `HTTP error! status: ${response.status}`)) })
        } else if (response instanceof Error) {
          shouldDismiss = false
          this.create({ id, type: "error", ...(await resolveSettings(data.error, response)) })
        } else if (data.success !== undefined) {
          shouldDismiss = false
          this.create({ id, type: "success", ...(await resolveSettings(data.success, response)) })
        }
      })
      .catch(async (error) => {
        result = ["reject", error]
        if (data.error !== undefined) {
          shouldDismiss = false
          this.create({ id, type: "error", ...(await resolveSettings(data.error, error)) })
        }
      })
      .finally(() => {
        if (shouldDismiss) {
          this.dismiss(id) // still loading and will be indefinitely: dismiss it
          id = undefined
        }
        data.finally?.call(data)
      })
    const unwrap = () => new Promise((resolve, reject) => original.then(() => (result[0] === "reject" ? reject(result[1]) : resolve(result[1]))).catch(reject))
    if (typeof id !== "string" && typeof id !== "number") return { unwrap }
    return Object.assign(Object(id), { unwrap })
  }

  getActiveToasts = () => this.toasts.filter((toast) => !this.dismissedToasts.has(toast.id))
}

function isHttpResponse(data) {
  return data && typeof data === "object" && "ok" in data && typeof data.ok === "boolean" && "status" in data && typeof data.status === "number"
}

const store = new Store()

/**
 * Shows a toast and returns its id. Same signature as sonner's `toast(message, data)`.
 * @param {string|Node|(() => string)} message the title
 * @param {object} [data] sonner's ExternalToast: `description`, `type`, `id`, `duration`, `position`, `dismissible`, `closeButton`, `richColors`,
 *   `invert`, `icon`, `action`/`cancel` (`{ label, onClick }`), `onDismiss`, `onAutoClose`, `className`, `classNames`, `style`, `unstyled`
 * @returns {string|number}
 */
export const toast = Object.assign(
  (message, data) => {
    const id = data?.id || toastsCounter++
    store.addToast({ title: message, ...data, id })
    return id
  },
  {
    success: store.success,
    info: store.info,
    warning: store.warning,
    error: store.error,
    custom: store.custom,
    message: store.message,
    promise: store.promise,
    dismiss: store.dismiss,
    loading: store.loading,
    getHistory: () => store.toasts,
    getToasts: () => store.getActiveToasts(),
  },
)

const cn = (...classes) => classes.filter(Boolean).join(" ")
const kebab = (name) => (name.startsWith("--") ? name : name.replace(/[A-Z]/g, (letter) => `-${letter.toLowerCase()}`))

/** React DOM sets `data-*` booleans as "true"/"false" and omits undefined/null. */
function setAttribute(el, name, value) {
  if (value === undefined || value === null) el.removeAttribute(name)
  else if (el.getAttribute(name) !== String(value)) el.setAttribute(name, String(value))
}

/** Applies a style object as custom/inline properties, removing the ones this helper set earlier and that are gone. */
function applyStyle(el, style) {
  const previous = el.__vars || new Set()
  const next = new Set()
  Object.entries(style).forEach(([name, value]) => {
    if (value === undefined || value === null || value === "") return
    const property = kebab(name)
    next.add(property)
    if (el.style.getPropertyValue(property) !== String(value)) el.style.setProperty(property, String(value))
  })
  previous.forEach((property) => next.has(property) || el.style.removeProperty(property))
  el.__vars = next
}

function assignOffset(defaultOffset, mobileOffset) {
  const styles = {}
  ;[defaultOffset, mobileOffset].forEach((offset, index) => {
    const prefix = index === 1 ? "--mobile-offset" : "--offset"
    const fallback = index === 1 ? MOBILE_VIEWPORT_OFFSET : VIEWPORT_OFFSET
    const value = (side) => (typeof offset?.[side] === "number" ? `${offset[side]}px` : offset[side])
    if (typeof offset === "number" || typeof offset === "string") {
      SIDES.forEach((side) => (styles[`${prefix}-${side}`] = typeof offset === "number" ? `${offset}px` : offset))
    } else if (offset && typeof offset === "object") {
      SIDES.forEach((side) => (styles[`${prefix}-${side}`] = offset[side] === undefined ? fallback : value(side)))
    } else {
      SIDES.forEach((side) => (styles[`${prefix}-${side}`] = fallback))
    }
  })
  return styles
}

const documentDirection = () => {
  const attribute = document.documentElement.getAttribute("dir")
  return attribute === "auto" || !attribute ? window.getComputedStyle(document.documentElement).direction : attribute
}

const defaultSwipeDirections = (position) => position.split("-").filter(Boolean)

const el = (tag, attrs = {}, ...children) => {
  const node = document.createElement(tag)
  Object.entries(attrs).forEach(([name, value]) => value !== undefined && value !== null && node.setAttribute(name, String(value)))
  node.append(...children.filter((child) => child !== null && child !== undefined))
  return node
}

const loaderBars = () => Array.from({ length: 12 }, () => el("div", { class: "sonner-loading-bar" }))

/** Everything the stack remembers about one toast (what the React `Toast` component keeps in state and refs). */
class Entry {
  constructor(data) {
    this.data = data
    this.version = 0
    this.el = null
    this.mounted = false
    this.removed = false
    this.swiping = false
    this.swipeOut = false
    this.isSwiped = false
    this.swipeDirection = null
    this.swipeOutDirection = null
    this.offsetBeforeRemove = 0
    this.initialHeight = 0
    this.offset = 0
    this.remainingTime = TOAST_LIFETIME
    this.closeTimerStart = 0
    this.lastCloseTimerStart = 0
    this.timeoutId = null
    this.timerKey = null
    this.dragStartTime = null
    this.pointerStart = null
  }
}

/**
 * One Toaster: renders the `<ol data-sonner-toaster>` lists and the `<li data-sonner-toast>` toasts into `root` (the `<section>` of the
 * Toaster), keeps their stacking variables (`--index`, `--offset`, `--initial-height`...) current, runs auto-dismiss timers, hover
 * expansion, swipe-to-dismiss and the hotkey, exactly like the sonner `Toaster` + `Toast` components.
 */
export class ToastStack {
  /**
   * @param {HTMLElement} root the Toaster `<section>`
   * @param {object} [config]
   * @param {string} [config.position="bottom-right"]
   * @param {string[]} [config.hotkey=["altKey","KeyT"]]
   * @param {boolean} [config.expand] keep the stack expanded
   * @param {boolean} [config.closeButton]
   * @param {string} [config.className] class of every list (`<ol>`)
   * @param {number|string|object} [config.offset]
   * @param {number|string|object} [config.mobileOffset]
   * @param {"light"|"dark"|"system"} [config.theme="light"]
   * @param {boolean} [config.richColors]
   * @param {boolean} [config.invert]
   * @param {number} [config.duration] default lifetime in ms
   * @param {object} [config.style] inline style of every list
   * @param {number} [config.visibleToasts=3]
   * @param {object} [config.toastOptions] `duration`, `closeButton`, `className`, `descriptionClassName`, `style`, `unstyled`, `classNames`, `closeButtonAriaLabel`, `actionButtonStyle`, `cancelButtonStyle`
   * @param {string} [config.dir] `ltr`, `rtl` or `auto`
   * @param {number} [config.gap=14]
   * @param {string} [config.toasterId] only toasts created with this `toasterId` are shown (default: those without one)
   * @param {string[]} [config.swipeDirections]
   * @param {(name: string) => Node|null} [config.iconFor] icon markup per type (`success`, `info`, `warning`, `error`, `loading`, `close`)
   * @param {(name: string, detail: object) => void} [config.emit] receives `dismiss` and `auto-close`
   */
  constructor(root, config = {}) {
    this.root = root
    this.config = config
    this.toasts = []
    this.entries = new Map()
    this.heights = []
    this.expanded = false
    this.interacting = false
    this.documentHidden = document.hidden
    this.lists = new Map()
    this.lastList = null
    this.lastFocused = null
    this.focusWithin = false
    this.connected = false
    this.timeouts = new Set()
    this.theme = this.#resolveTheme()
  }

  /** Subscribes to the store, the document hotkey, visibility and (for `theme: "system"`) the color scheme. */
  connect() {
    if (this.connected) return
    this.connected = true
    this.unsubscribe = store.subscribe((message) => this.#onMessage(message))
    this.onKeyDown = (event) => this.#onKeyDown(event)
    this.onVisibility = () => {
      this.documentHidden = document.hidden
      this.#render()
    }
    document.addEventListener("keydown", this.onKeyDown)
    document.addEventListener("visibilitychange", this.onVisibility)
    if (this.config.theme === "system" && window.matchMedia) {
      this.media = window.matchMedia("(prefers-color-scheme: dark)")
      this.onScheme = ({ matches }) => {
        this.theme = matches ? "dark" : "light"
        this.#render()
      }
      this.media.addEventListener("change", this.onScheme)
    }
  }

  /** Removes everything the stack created, clears every timer and unsubscribes (a Turbo cache restore must not leave toasts behind). */
  disconnect() {
    if (!this.connected) return
    this.connected = false
    this.unsubscribe?.()
    document.removeEventListener("keydown", this.onKeyDown)
    document.removeEventListener("visibilitychange", this.onVisibility)
    this.media?.removeEventListener("change", this.onScheme)
    this.timeouts.forEach((id) => clearTimeout(id))
    this.timeouts.clear()
    this.entries.forEach((entry) => clearTimeout(entry.timeoutId))
    this.entries.clear()
    this.lists.forEach((list) => list.remove())
    this.lists.clear()
    this.toasts = []
    this.heights = []
    this.announcer?.remove()
    this.announcer = null
    this.#restoreFocus()
  }

  /** The `<ol>` that currently holds the toasts (the one the hotkey focuses), or null when no toast is shown. */
  get list() {
    return this.lastList
  }

  // ---- store messages (Toaster) ---------------------------------------------------------------------------------------------

  #later(fn, delay = 0) {
    const id = setTimeout(() => {
      this.timeouts.delete(id)
      if (this.connected) fn()
    }, delay)
    this.timeouts.add(id)
  }

  #onMessage(message) {
    if (message.dismiss) {
      requestAnimationFrame(() => {
        if (!this.connected) return
        const index = this.toasts.findIndex((t) => t.id === message.id)
        if (index === -1) return
        this.toasts[index] = { ...this.toasts[index], delete: true }
        const entry = this.entries.get(message.id)
        if (entry) {
          entry.data = this.toasts[index]
          entry.version += 1
          this.#dismissed(entry)
        }
        this.#render()
      })
      return
    }
    this.#later(() => this.#upsert(message)) // sonner defers one task to prevent batching
  }

  #accepts(toast) {
    const id = this.config.toasterId
    return id ? toast.toasterId === id : !toast.toasterId
  }

  #upsert(message) {
    const index = this.toasts.findIndex((t) => t.id === message.id)
    if (index === -1 && !this.#accepts(message)) return // sonner renders no Toast for it: no entry, no timer, no callbacks
    if (index !== -1) {
      this.toasts[index] = { ...this.toasts[index], ...message }
      const entry = this.entries.get(message.id)
      if (entry) {
        entry.data = this.toasts[index]
        entry.version += 1
        this.#rebuild(entry)
      }
      this.#render()
      if (entry) this.#measure(entry)
      return
    }
    this.toasts.unshift(message)
    const entry = new Entry(message)
    this.entries.set(message.id, entry)
    this.#render() // creates the <li> with data-mounted="false"
    this.#mount(entry)
  }

  // ---- toast lifecycle (Toast) ----------------------------------------------------------------------------------------------

  #position(entry) {
    return entry.el?.closest("[data-sonner-toaster]")?.__position
  }

  #mount(entry) {
    if (!entry.el) return
    const height = entry.el.getBoundingClientRect().height // forces the first style computation: the enter transition starts from here
    entry.initialHeight = height
    this.heights.unshift({ toastId: entry.data.id, height, position: entry.data.position })
    entry.mounted = true
    this.#render()
    this.#measure(entry)
    if (entry.data.type === "error") this.#announce(entry.data)
  }

  /** Keeps the stored height current: measured with `height: auto`, as sonner's layout effect does. */
  #measure(entry) {
    if (!entry.el || !entry.mounted) return
    const original = entry.el.style.height
    entry.el.style.height = "auto"
    const height = entry.el.getBoundingClientRect().height
    entry.el.style.height = original
    entry.initialHeight = height
    const known = this.heights.find((h) => h.toastId === entry.data.id)
    if (known) known.height = height
    else this.heights.unshift({ toastId: entry.data.id, height, position: entry.data.position })
    this.#render()
  }

  #deleteToast(entry) {
    if (entry.removed) return
    clearTimeout(entry.timeoutId) // a toast closed by hand must not also report an auto-close
    entry.removed = true
    entry.offsetBeforeRemove = entry.offset
    this.heights = this.heights.filter((h) => h.toastId !== entry.data.id)
    this.#later(() => this.#removeToast(entry.data), TIME_BEFORE_UNMOUNT)
    this.#render()
  }

  #removeToast(data) {
    const current = this.toasts.find((t) => t.id === data.id)
    if (!current?.delete) store.dismiss(data.id)
    this.toasts = this.toasts.filter((t) => t.id !== data.id)
    const entry = this.entries.get(data.id)
    if (entry) {
      clearTimeout(entry.timeoutId)
      entry.el?.remove()
      this.entries.delete(data.id)
    }
    if (this.toasts.length <= 1) this.expanded = false
    this.#render()
  }

  /** The toast is dismissed (by `toast.dismiss`, its close button or a swipe): leave, then tell the caller. */
  #dismissed(entry) {
    if (entry.removed) return
    this.#deleteToast(entry)
    entry.data.onDismiss?.call(entry.data, entry.data)
    this.config.emit?.("dismiss", { id: entry.data.id })
  }

  #duration(entry) {
    const options = this.config.toastOptions || {}
    return entry.data.duration || (options.duration ?? this.config.duration) || TOAST_LIFETIME
  }

  /** (Re)arms the auto-dismiss timer only when something it depends on changed, like the React effect. */
  #syncTimer(entry) {
    const { data } = entry
    const key = [this.expanded, this.interacting, this.documentHidden, data.type, entry.version, this.#duration(entry)].join("|")
    if (entry.removed || key === entry.timerKey) return
    const durationChanged = !entry.timerKey || entry.timerKey.split("|")[5] !== key.split("|")[5]
    entry.timerKey = key
    if (durationChanged) entry.remainingTime = this.#duration(entry)
    clearTimeout(entry.timeoutId)
    if ((data.promise && data.type === "loading") || data.duration === Infinity || data.type === "loading") return

    if (this.expanded || this.interacting || this.documentHidden) {
      if (entry.lastCloseTimerStart < entry.closeTimerStart) entry.remainingTime -= Date.now() - entry.closeTimerStart
      entry.lastCloseTimerStart = Date.now()
    } else {
      if (entry.remainingTime === Infinity) return
      entry.closeTimerStart = Date.now()
      entry.timeoutId = setTimeout(() => {
        data.onAutoClose?.call(data, data)
        this.config.emit?.("auto-close", { id: data.id })
        this.#deleteToast(entry)
      }, entry.remainingTime)
    }
  }

  // ---- rendering ------------------------------------------------------------------------------------------------------------

  #resolveTheme() {
    const theme = this.config.theme || "light"
    if (theme !== "system") return theme
    return window.matchMedia?.("(prefers-color-scheme: dark)").matches ? "dark" : "light"
  }

  #visibleToasts() {
    const id = this.config.toasterId
    return this.toasts.filter((t) => (id ? t.toasterId === id : !t.toasterId))
  }

  #render() {
    if (!this.connected) return
    const filtered = this.#visibleToasts()
    const wanted = filtered.length ? [...new Set([this.config.position || "bottom-right", ...filtered.filter((t) => t.position).map((t) => t.position)])] : []

    this.lists.forEach((list, position) => {
      if (wanted.includes(position)) return
      list.remove()
      this.lists.delete(position)
    })
    wanted.forEach((position, index) => {
      const list = this.#list(position)
      this.#applyList(list, position)
      const group = filtered.filter((t) => (!t.position && index === 0) || t.position === position)
      this.#renderGroup(list, position, group, filtered)
    })
    this.lastList = wanted.length ? this.lists.get(wanted[wanted.length - 1]) : null
    this.entries.forEach((entry) => entry.el && this.#syncTimer(entry))
  }

  #list(position) {
    let list = this.lists.get(position)
    if (list) return list
    list = el("ol", { tabindex: -1 })
    list.__position = position
    list.addEventListener("focusin", (event) => {
      if (event.target instanceof HTMLElement && event.target.dataset.dismissible === "false") return
      if (!this.focusWithin) {
        this.focusWithin = true
        this.lastFocused = event.relatedTarget
      }
    })
    list.addEventListener("focusout", (event) => {
      if (this.focusWithin && !list.contains(event.relatedTarget)) {
        this.focusWithin = false
        this.#restoreFocus()
      }
    })
    list.addEventListener("mouseenter", () => this.#setExpanded(true))
    list.addEventListener("mousemove", () => this.#setExpanded(true))
    list.addEventListener("mouseleave", () => !this.interacting && this.#setExpanded(false))
    list.addEventListener("dragend", () => this.#setExpanded(false))
    list.addEventListener("pointerdown", (event) => {
      if (event.target instanceof HTMLElement && event.target.dataset.dismissible === "false") return
      this.#setInteracting(true)
    })
    list.addEventListener("pointerup", () => this.#setInteracting(false))
    this.lists.set(position, list)
    this.root.append(list)
    return list
  }

  #setExpanded(value) {
    if (this.expanded === value) return
    this.expanded = value
    this.#render()
  }

  #setInteracting(value) {
    if (this.interacting === value) return
    this.interacting = value
    this.#render()
  }

  #applyList(list, position) {
    const [y, x] = position.split("-")
    const dir = this.config.dir || documentDirection()
    setAttribute(list, "dir", dir === "auto" ? documentDirection() : dir)
    setAttribute(list, "class", this.config.className ?? "")
    setAttribute(list, "data-sonner-toaster", true)
    setAttribute(list, "data-sonner-theme", this.theme)
    setAttribute(list, "data-y-position", y)
    setAttribute(list, "data-x-position", x)
    applyStyle(list, {
      "--front-toast-height": `${this.heights[0]?.height || 0}px`,
      "--width": `${TOAST_WIDTH}px`,
      "--gap": `${this.config.gap ?? GAP}px`,
      ...this.config.style,
      ...assignOffset(this.config.offset, this.config.mobileOffset),
    })
  }

  #renderGroup(list, position, group, filtered) {
    const options = this.config.toastOptions || {}
    const visibleToasts = this.config.visibleToasts ?? VISIBLE_TOASTS_AMOUNT
    const gap = this.config.gap ?? GAP
    const [y, x] = position.split("-")
    const keep = []

    group.forEach((data, index) => {
      const entry = this.entries.get(data.id)
      if (!entry) return
      entry.data = data
      if (!entry.el) this.#create(entry)
      keep.push(entry.el)

      const sameStack = filtered.filter((t) => t.position == data.position) // eslint-disable-line eqeqeq
      const heights = this.heights.filter((h) => h.position == data.position) // eslint-disable-line eqeqeq
      const heightIndex = heights.findIndex((h) => h.toastId === data.id) || 0
      const before = heights.reduce((sum, height, i) => (i >= heightIndex ? sum : sum + height.height), 0)
      entry.offset = heightIndex * gap + before

      const dismissible = data.dismissible !== false
      const richColors = data.richColors ?? this.config.richColors
      const invert = data.invert || this.config.invert
      const expandByDefault = this.config.expand
      setAttribute(entry.el, "tabindex", 0)
      setAttribute(entry.el, "data-sonner-toast", "")
      setAttribute(entry.el, "data-rich-colors", richColors)
      setAttribute(entry.el, "data-styled", !(data.jsx || data.unstyled || options.unstyled))
      setAttribute(entry.el, "data-mounted", entry.mounted)
      setAttribute(entry.el, "data-promise", Boolean(data.promise))
      setAttribute(entry.el, "data-swiped", entry.isSwiped)
      setAttribute(entry.el, "data-removed", entry.removed)
      setAttribute(entry.el, "data-visible", index + 1 <= visibleToasts)
      setAttribute(entry.el, "data-y-position", y)
      setAttribute(entry.el, "data-x-position", x)
      setAttribute(entry.el, "data-index", index)
      setAttribute(entry.el, "data-front", index === 0)
      setAttribute(entry.el, "data-swiping", entry.swiping)
      setAttribute(entry.el, "data-dismissible", dismissible)
      setAttribute(entry.el, "data-type", data.type)
      setAttribute(entry.el, "data-invert", invert)
      setAttribute(entry.el, "data-swipe-out", entry.swipeOut)
      setAttribute(entry.el, "data-swipe-direction", entry.swipeOutDirection)
      setAttribute(entry.el, "data-expanded", Boolean(this.expanded || (expandByDefault && entry.mounted)))
      setAttribute(entry.el, "data-testid", data.testId)
      applyStyle(entry.el, {
        "--index": index,
        "--toasts-before": index,
        "--z-index": sameStack.length - index,
        "--offset": `${entry.removed ? entry.offsetBeforeRemove : entry.offset}px`,
        "--initial-height": expandByDefault ? "auto" : `${entry.initialHeight}px`,
        ...options.style,
        ...data.style,
      })
    })

    // Newest first, and drop the toasts that left this list (a position change) or were removed.
    keep.forEach((node, i) => list.children[i] === node || list.insertBefore(node, list.children[i] || null))
    ;[...list.children].forEach((child) => keep.includes(child) || child.remove())
  }

  // ---- building one toast ---------------------------------------------------------------------------------------------------

  #create(entry) {
    const li = el("li")
    entry.el = li
    li.addEventListener("pointerdown", (event) => this.#onPointerDown(entry, event))
    li.addEventListener("pointerup", () => this.#onPointerUp(entry))
    li.addEventListener("pointermove", (event) => this.#onPointerMove(entry, event))
    li.addEventListener("dragend", () => {
      entry.swiping = false
      entry.swipeDirection = null
      entry.pointerStart = null
      this.#render()
    })
    this.#rebuild(entry)
  }

  #classes(entry) {
    const { data } = entry
    const options = this.config.toastOptions || {}
    const named = options.classNames || {}
    const own = data.classNames || {}
    return { named, own, options, type: data.type }
  }

  /** Builds (or rebuilds after an update) the class and the children of the toast: close button, icon, content, cancel, action. */
  #rebuild(entry) {
    const { data } = entry
    const { named, own, options, type } = this.#classes(entry)
    const dismissible = data.dismissible !== false
    const disabled = type === "loading"
    const li = entry.el
    li.className = cn(options.className, data.className, named.toast, own.toast, named.default, named[type], own[type])
    if (!li.hasAttribute("class")) li.setAttribute("class", "")

    const children = []
    const closeButton = data.closeButton ?? options.closeButton ?? this.config.closeButton
    if (closeButton && !data.jsx && type !== "loading") {
      const close = el("button", { "aria-label": options.closeButtonAriaLabel || "Close toast", "data-disabled": disabled, "data-close-button": true, class: cn(named.closeButton, own.closeButton) })
      close.append(this.config.iconFor?.("close") ?? "")
      close.addEventListener("click", () => {
        if (disabled || !dismissible) return
        this.#dismissed(entry)
      })
      children.push(close)
    }

    // `iconFor(type)` is a node, null (no icon registered) or false (the app switched that type's icon off, sonner's `icons[type] === null`).
    const typedIcon = type ? this.config.iconFor?.(type) : null
    if ((type || data.icon || data.promise) && data.icon !== null && (typedIcon !== false || data.icon)) {
      const icon = el("div", { "data-icon": "", class: cn(named.icon, own.icon) })
      if (data.promise || (type === "loading" && !data.icon)) icon.append(this.#node(data.icon, { clone: true }) ?? this.#loadingIcon(entry))
      if (type !== "loading") icon.append(this.#node(data.icon, { clone: true }) ?? (typedIcon || ""))
      children.push(icon)
    }

    const title = el("div", { "data-title": "", class: cn(named.title, own.title) })
    const titleValue = data.jsx ? data.jsx : typeof data.title === "function" ? data.title() : data.title
    title.append(this.#node(titleValue) ?? "")
    const content = el("div", { "data-content": "", class: cn(named.content, own.content) }, title)
    if (data.description) {
      const description = el("div", { "data-description": "", class: cn(options.descriptionClassName, data.descriptionClassName, named.description, own.description) })
      description.append(this.#node(typeof data.description === "function" ? data.description() : data.description) ?? "")
      content.append(description)
    }
    children.push(content)

    if (data.cancel instanceof Node) children.push(data.cancel)
    else if (data.cancel?.label !== undefined) children.push(this.#button(entry, "cancel", data.cancel, options.cancelButtonStyle || this.config.cancelButtonStyle, cn(named.cancelButton, own.cancelButton)))
    if (data.action instanceof Node) children.push(data.action)
    else if (data.action?.label !== undefined) children.push(this.#button(entry, "action", data.action, options.actionButtonStyle || this.config.actionButtonStyle, cn(named.actionButton, own.actionButton)))

    li.replaceChildren(...children)
  }

  /** Shared icon templates are cloned; the caller's own nodes (custom content, titles) are used as they are, so their listeners survive. */
  #node(value, { clone = false } = {}) {
    if (value === undefined || value === null || value === false) return null
    if (value instanceof Node) return clone ? value.cloneNode(true) : value
    return document.createTextNode(String(value))
  }

  #loadingIcon(entry) {
    const named = this.#classes(entry)
    const loaderClass = cn(named.named.loader, named.own.loader)
    const visible = entry.data.type === "loading"
    const loading = this.config.iconFor?.("loading")
    if (loading) return el("div", { class: cn(loaderClass, "sonner-loader"), "data-visible": visible }, loading)
    return el("div", { class: cn("sonner-loading-wrapper", loaderClass), "data-visible": visible }, el("div", { class: "sonner-spinner" }, ...loaderBars()))
  }

  #button(entry, kind, action, style, className) {
    const button = el("button", { "data-button": true, [`data-${kind}`]: true, class: className })
    if (style) applyStyle(button, style)
    button.append(String(action.label))
    button.addEventListener("click", (event) => {
      if (kind === "cancel") {
        if (entry.data.dismissible === false) return
        action.onClick?.call(action, event)
        this.#deleteToast(entry)
      } else {
        action.onClick?.call(action, event)
        if (event.defaultPrevented) return
        this.#deleteToast(entry)
      }
    })
    return button
  }

  // ---- swipe (Toast pointer handlers) ---------------------------------------------------------------------------------------

  #onPointerDown(entry, event) {
    if (event.button === 2) return
    if (entry.data.type === "loading" || entry.data.dismissible === false) return
    entry.dragStartTime = new Date()
    entry.offsetBeforeRemove = entry.offset
    event.target.setPointerCapture?.(event.pointerId) // keep the pointer even when it leaves the toast while swiping
    if (event.target.tagName === "BUTTON") return
    entry.swiping = true
    entry.pointerStart = { x: event.clientX, y: event.clientY }
    this.#render()
  }

  #onPointerUp(entry) {
    if (entry.swipeOut || entry.data.dismissible === false) return
    entry.pointerStart = null
    const amount = (name) => Number((entry.el.style.getPropertyValue(name) || "").replace("px", "") || 0)
    const swipeAmountX = amount("--swipe-amount-x")
    const swipeAmountY = amount("--swipe-amount-y")
    const timeTaken = new Date().getTime() - entry.dragStartTime?.getTime()
    const swipeAmount = entry.swipeDirection === "x" ? swipeAmountX : swipeAmountY
    const velocity = Math.abs(swipeAmount) / timeTaken
    if (Math.abs(swipeAmount) >= SWIPE_THRESHOLD || velocity > 0.11) {
      entry.offsetBeforeRemove = entry.offset
      entry.data.onDismiss?.call(entry.data, entry.data)
      this.config.emit?.("dismiss", { id: entry.data.id })
      entry.swipeOutDirection = entry.swipeDirection === "x" ? (swipeAmountX > 0 ? "right" : "left") : swipeAmountY > 0 ? "down" : "up"
      this.#deleteToast(entry)
      entry.swipeOut = true
      this.#render()
      return
    }
    entry.el.style.setProperty("--swipe-amount-x", "0px")
    entry.el.style.setProperty("--swipe-amount-y", "0px")
    entry.isSwiped = false
    entry.swiping = false
    entry.swipeDirection = null
    this.#render()
  }

  #onPointerMove(entry, event) {
    if (!entry.pointerStart || entry.data.dismissible === false) return
    if (window.getSelection()?.toString().length > 0) return
    const yDelta = event.clientY - entry.pointerStart.y
    const xDelta = event.clientX - entry.pointerStart.x
    const directions = this.config.swipeDirections ?? defaultSwipeDirections(this.#position(entry) ?? this.config.position ?? "bottom-right")
    const direction = entry.swipeDirection
    if (!direction && (Math.abs(xDelta) > 1 || Math.abs(yDelta) > 1)) entry.swipeDirection = Math.abs(xDelta) > Math.abs(yDelta) ? "x" : "y"

    const swipeAmount = { x: 0, y: 0 }
    const dampening = (delta) => 1 / (1.5 + Math.abs(delta) / 20)
    const along = (delta, forward) => {
      if (forward) return delta
      const dampened = delta * dampening(delta)
      return Math.abs(dampened) < Math.abs(delta) ? dampened : delta
    }
    if (direction === "y") {
      if (directions.includes("top") || directions.includes("bottom")) swipeAmount.y = along(yDelta, (directions.includes("top") && yDelta < 0) || (directions.includes("bottom") && yDelta > 0))
    } else if (direction === "x") {
      if (directions.includes("left") || directions.includes("right")) swipeAmount.x = along(xDelta, (directions.includes("left") && xDelta < 0) || (directions.includes("right") && xDelta > 0))
    }
    if (Math.abs(swipeAmount.x) > 0 || Math.abs(swipeAmount.y) > 0) entry.isSwiped = true
    entry.el.style.setProperty("--swipe-amount-x", `${swipeAmount.x}px`)
    entry.el.style.setProperty("--swipe-amount-y", `${swipeAmount.y}px`)
    this.#render()
  }

  // ---- keyboard, focus, announcements ---------------------------------------------------------------------------------------

  #onKeyDown(event) {
    const hotkey = this.config.hotkey || ["altKey", "KeyT"]
    if (hotkey.every((key) => event[key] || event.code === key)) {
      this.#setExpanded(true)
      this.lastList?.focus()
    }
    if (event.code === "Escape" && this.lastList && (document.activeElement === this.lastList || this.lastList.contains(document.activeElement))) this.#setExpanded(false)
  }

  #restoreFocus() {
    if (!this.lastFocused) return
    this.lastFocused.focus?.({ preventScroll: true })
    this.lastFocused = null
    this.focusWithin = false
  }

  /** An error must interrupt: the Toaster section is `aria-live="polite"` like sonner's, so errors are also written to an assertive region. */
  #announce(data) {
    const text = [data.title, data.description].filter((part) => typeof part === "string").join(". ")
    if (!text) return
    if (!this.announcer) {
      this.announcer = el("div", { role: "alert", "data-shadcn-sonner-announcer": "", style: "position:absolute;width:1px;height:1px;margin:-1px;padding:0;overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap;border:0" })
      document.body.append(this.announcer)
    }
    this.announcer.textContent = ""
    this.#later(() => (this.announcer.textContent = text), 50)
  }
}
