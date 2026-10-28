import { Controller } from "@hotwired/stimulus"
import { turboCacheRestore } from "chadcn/primitives/turbo_cache"

// shadcn Carousel (dev/port/specs/carousel.md). Host = the carousel root. The scrolling engine below is a re-implementation of
// embla-carousel 8.6.0 (MIT): the same measurements, snaps, scroll physics, drag, loop and slide focus, writing the same inline
// transforms, so the observed boxes equal the oracle's. The names follow embla's modules (the spec cites embla:<line>).
// Option values are JSON only (the function forms of align and watch* are not supported, spec Deviations).

const isNumber = (value) => typeof value === "number"
const isString = (value) => typeof value === "string"
const isObject = (value) => Object.prototype.toString.call(value) === "[object Object]"
const mathAbs = Math.abs
const mathSign = Math.sign
const deltaAbs = (b, a) => mathAbs(b - a)
const roundToTwoDecimals = (n) => Math.round(n * 100) / 100
const arrayKeys = (array) => Object.keys(array).map(Number)
const arrayLastIndex = (array) => Math.max(0, array.length - 1)
const arrayLast = (array) => array[arrayLastIndex(array)]
const arrayIsLastIndex = (array, index) => index === arrayLastIndex(array)
const arrayFromNumber = (n, startAt = 0) => Array.from(Array(n), (_, i) => startAt + i)

function factorAbs(b, a) {
  if (b === 0 || a === 0) return 0
  if (mathAbs(b) <= mathAbs(a)) return 0
  return mathAbs(deltaAbs(mathAbs(b), mathAbs(a)) / b)
}

function objectsMergeDeep(objectA, objectB) {
  return [objectA, objectB].reduce((merged, current) => {
    Object.keys(current).forEach((key) => {
      const a = merged[key]
      const b = current[key]
      merged[key] = isObject(a) && isObject(b) ? objectsMergeDeep(a, b) : b
    })
    return merged
  }, {})
}

const DEFAULT_OPTIONS = {
  align: "center", axis: "x", container: null, slides: null, containScroll: "trimSnaps", direction: "ltr",
  slidesToScroll: 1, inViewThreshold: 0, breakpoints: {}, dragFree: false, dragThreshold: 10, loop: false,
  skipSnaps: false, duration: 25, startIndex: 0, active: true, watchDrag: true, watchResize: true,
  watchSlides: true, watchFocus: true
}

function Limit(min = 0, max = 0) {
  const length = mathAbs(min - max)
  const reachedMin = (n) => n < min
  const reachedMax = (n) => n > max
  const reachedAny = (n) => reachedMin(n) || reachedMax(n)
  const constrain = (n) => (!reachedAny(n) ? n : reachedMin(n) ? min : max)
  const removeOffset = (n) => (!length ? n : n - length * Math.ceil((n - max) / length))
  return { length, max, min, constrain, reachedAny, reachedMax, reachedMin, removeOffset }
}

function Counter(max, start, loop) {
  const { constrain } = Limit(0, max)
  const loopEnd = max + 1
  const withinLimit = (n) => (!loop ? constrain(n) : mathAbs((loopEnd + n) % loopEnd))
  let counter = withinLimit(start)
  const self = {
    get: () => counter,
    set(n) { counter = withinLimit(n); return self },
    add: (n) => Counter(max, counter, loop).set(counter + n),
    clone: () => Counter(max, counter, loop)
  }
  return self
}

function Vector1D(initialValue) {
  let value = initialValue
  const read = (n) => (isNumber(n) ? n : n.get())
  return {
    get: () => value,
    set(n) { value = read(n) },
    add(n) { value += read(n) },
    subtract(n) { value -= read(n) }
  }
}

function EventStore() {
  let listeners = []
  const self = {
    add(node, type, handler, options = { passive: true }) {
      node.addEventListener(type, handler, options)
      listeners.push(() => node.removeEventListener(type, handler, options))
      return self
    },
    clear() { listeners = listeners.filter((remove) => remove()) }
  }
  return self
}

function Axis(axis, contentDirection) {
  const isRightToLeft = contentDirection === "rtl"
  const isVertical = axis === "y"
  const sign = !isVertical && isRightToLeft ? -1 : 1
  return {
    scroll: isVertical ? "y" : "x",
    cross: isVertical ? "x" : "y",
    startEdge: isVertical ? "top" : isRightToLeft ? "right" : "left",
    endEdge: isVertical ? "bottom" : isRightToLeft ? "left" : "right",
    measureSize: ({ height, width }) => (isVertical ? height : width),
    direction: (n) => n * sign
  }
}

function Alignment(align, viewSize) {
  const end = (n) => viewSize - n
  const predefined = { start: () => 0, center: (n) => end(n) / 2, end }
  return { measure: (n) => (predefined[align] || predefined.center)(n) }
}

function measureNode({ offsetTop, offsetLeft, offsetWidth, offsetHeight }) {
  return {
    top: offsetTop, right: offsetLeft + offsetWidth, bottom: offsetTop + offsetHeight, left: offsetLeft,
    width: offsetWidth, height: offsetHeight
  }
}

function Animations(ownerDocument, ownerWindow, update, render) {
  const documentVisibleHandler = EventStore()
  const fixedTimeStep = 1000 / 60
  let lastTimeStamp = null
  let accumulatedTime = 0
  let animationId = 0

  function reset() {
    lastTimeStamp = null
    accumulatedTime = 0
  }
  function animate(timeStamp) {
    if (!animationId) return
    if (!lastTimeStamp) {
      lastTimeStamp = timeStamp
      update()
      update()
    }
    accumulatedTime += timeStamp - lastTimeStamp
    lastTimeStamp = timeStamp
    while (accumulatedTime >= fixedTimeStep) {
      update()
      accumulatedTime -= fixedTimeStep
    }
    render(accumulatedTime / fixedTimeStep)
    if (animationId) animationId = ownerWindow.requestAnimationFrame(animate)
  }
  function stop() {
    ownerWindow.cancelAnimationFrame(animationId)
    reset()
    animationId = 0
  }
  return {
    init() { documentVisibleHandler.add(ownerDocument, "visibilitychange", () => { if (ownerDocument.hidden) reset() }) },
    destroy() { stop(); documentVisibleHandler.clear() },
    start() { if (!animationId) animationId = ownerWindow.requestAnimationFrame(animate) },
    stop,
    update,
    render
  }
}

function ScrollBody(location, offsetLocation, previousLocation, target, baseDuration, baseFriction) {
  let scrollVelocity = 0
  let scrollDirection = 0
  let scrollDuration = baseDuration
  let scrollFriction = baseFriction
  let rawLocation = location.get()
  let rawLocationPrevious = 0
  const self = {
    seek() {
      const displacement = target.get() - location.get()
      let scrollDistance = 0
      if (!scrollDuration) {
        scrollVelocity = 0
        previousLocation.set(target)
        location.set(target)
        scrollDistance = displacement
      } else {
        previousLocation.set(location)
        scrollVelocity += displacement / scrollDuration
        scrollVelocity *= scrollFriction
        rawLocation += scrollVelocity
        location.add(scrollVelocity)
        scrollDistance = rawLocation - rawLocationPrevious
      }
      scrollDirection = mathSign(scrollDistance)
      rawLocationPrevious = rawLocation
      return self
    },
    settled: () => mathAbs(target.get() - offsetLocation.get()) < 0.001,
    duration: () => scrollDuration,
    direction: () => scrollDirection,
    velocity: () => scrollVelocity,
    useBaseDuration: () => self.useDuration(baseDuration),
    useBaseFriction: () => self.useFriction(baseFriction),
    useDuration(n) { scrollDuration = n; return self },
    useFriction(n) { scrollFriction = n; return self }
  }
  return self
}

function ScrollBounds(limit, location, target, scrollBody, viewSize) {
  const pullBackThreshold = viewSize * 0.1
  const edgeOffsetTolerance = viewSize * 0.5
  const frictionLimit = Limit(0.1, 0.99)
  function shouldConstrain() {
    return limit.reachedAny(target.get()) && limit.reachedAny(location.get())
  }
  return {
    shouldConstrain,
    constrain(pointerDown) {
      if (!shouldConstrain()) return
      const edge = limit.reachedMin(location.get()) ? "min" : "max"
      const diffToEdge = mathAbs(limit[edge] - location.get())
      const diffToTarget = target.get() - location.get()
      const friction = frictionLimit.constrain(diffToEdge / edgeOffsetTolerance)
      target.subtract(diffToTarget * friction)
      if (!pointerDown && mathAbs(diffToTarget) < pullBackThreshold) {
        target.set(limit.constrain(target.get()))
        scrollBody.useDuration(25).useBaseFriction()
      }
    }
  }
}

function ScrollContain(viewSize, contentSize, snapsAligned, containScroll, pixelTolerance) {
  const scrollBounds = Limit(-contentSize + viewSize, 0)
  const snapsBounded = snapsAligned.map((snapAligned, index) => {
    const { min, max } = scrollBounds
    const snap = scrollBounds.constrain(snapAligned)
    if (!index) return max
    if (arrayIsLastIndex(snapsAligned, index)) return min
    if (deltaAbs(min, snap) <= 1) return min
    if (deltaAbs(max, snap) <= 1) return max
    return snap
  }).map((bound) => parseFloat(bound.toFixed(3)))
  const scrollContainLimit = Limit(snapsBounded.lastIndexOf(snapsBounded[0]), snapsBounded.indexOf(arrayLast(snapsBounded)) + 1)
  function measureContained() {
    if (contentSize <= viewSize + pixelTolerance) return [scrollBounds.max]
    if (containScroll === "keepSnaps") return snapsBounded
    return snapsBounded.slice(scrollContainLimit.min, scrollContainLimit.max)
  }
  return { snapsContained: measureContained(), scrollContainLimit }
}

function ScrollLooper(contentSize, limit, location, vectors) {
  const jointSafety = 0.1
  const { reachedMin, reachedMax } = Limit(limit.min + jointSafety, limit.max + jointSafety)
  const shouldLoop = (direction) => (direction === 1 ? reachedMax(location.get()) : direction === -1 ? reachedMin(location.get()) : false)
  return {
    loop(direction) {
      if (!shouldLoop(direction)) return
      const loopDistance = contentSize * (direction * -1)
      vectors.forEach((v) => v.add(loopDistance))
    }
  }
}

function ScrollTarget(loop, scrollSnaps, contentSize, limit, targetVector) {
  const { reachedAny, removeOffset, constrain } = limit
  const minDistance = (distances) => distances.concat().sort((a, b) => mathAbs(a) - mathAbs(b))[0]
  function shortcut(target, direction) {
    const targets = [target, target + contentSize, target - contentSize]
    if (!loop) return target
    if (!direction) return minDistance(targets)
    const matching = targets.filter((t) => mathSign(t) === direction)
    if (matching.length) return minDistance(matching)
    return arrayLast(targets) - contentSize
  }
  function findTargetSnap(target) {
    const distance = loop ? removeOffset(target) : constrain(target)
    const [{ index }] = scrollSnaps
      .map((snap, i) => ({ diff: shortcut(snap - distance, 0), index: i }))
      .sort((d1, d2) => mathAbs(d1.diff) - mathAbs(d2.diff))
    return { index, distance }
  }
  return {
    shortcut,
    byIndex(index, direction) {
      return { index, distance: shortcut(scrollSnaps[index] - targetVector.get(), direction) }
    },
    byDistance(distance, snap) {
      const target = targetVector.get() + distance
      const { index, distance: targetSnapDistance } = findTargetSnap(target)
      const reachedBound = !loop && reachedAny(target)
      if (!snap || reachedBound) return { index, distance }
      return { index, distance: distance + shortcut(scrollSnaps[index] - targetSnapDistance, 0) }
    }
  }
}

function ScrollTo(animation, indexCurrent, indexPrevious, scrollBody, scrollTarget, targetVector, eventHandler) {
  function scrollTo(target) {
    const distanceDiff = target.distance
    const indexDiff = target.index !== indexCurrent.get()
    targetVector.add(distanceDiff)
    if (distanceDiff) {
      if (scrollBody.duration()) {
        animation.start()
      } else {
        animation.update()
        animation.render(1)
        animation.update()
      }
    }
    if (indexDiff) {
      indexPrevious.set(indexCurrent.get())
      indexCurrent.set(target.index)
      eventHandler.emit("select")
    }
  }
  return {
    distance: (n, snap) => scrollTo(scrollTarget.byDistance(n, snap)),
    index: (n, direction) => scrollTo(scrollTarget.byIndex(indexCurrent.clone().set(n).get(), direction))
  }
}

function SlideSizes(axis, containerRect, slideRects, slides, readEdgeGap, ownerWindow) {
  const { measureSize, startEdge, endEdge } = axis
  const withEdgeGap = slideRects[0] && readEdgeGap
  const startGap = withEdgeGap ? mathAbs(containerRect[startEdge] - slideRects[0][startEdge]) : 0
  const endGap = withEdgeGap ? parseFloat(ownerWindow.getComputedStyle(arrayLast(slides)).getPropertyValue(`margin-${endEdge}`)) : 0
  const slideSizes = slideRects.map(measureSize)
  const slideSizesWithGaps = slideRects.map((rect, index, rects) => {
    if (!index) return slideSizes[index] + startGap
    if (arrayIsLastIndex(rects, index)) return slideSizes[index] + endGap
    return rects[index + 1][startEdge] - rect[startEdge]
  }).map(mathAbs)
  return { slideSizes, slideSizesWithGaps, startGap, endGap }
}

function SlidesToScroll(axis, viewSize, slidesToScroll, loop, containerRect, slideRects, startGap, endGap, pixelTolerance) {
  const { startEdge, endEdge, direction } = axis
  const byNumber = (array, groupSize) => arrayKeys(array).filter((i) => i % groupSize === 0).map((i) => array.slice(i, i + groupSize))
  function bySize(array) {
    if (!array.length) return []
    return arrayKeys(array).reduce((groups, rectB, index) => {
      const rectA = arrayLast(groups) || 0
      const isFirst = rectA === 0
      const isLast = rectB === arrayLastIndex(array)
      const edgeA = containerRect[startEdge] - slideRects[rectA][startEdge]
      const edgeB = containerRect[startEdge] - slideRects[rectB][endEdge]
      const gapA = !loop && isFirst ? direction(startGap) : 0
      const gapB = !loop && isLast ? direction(endGap) : 0
      const chunkSize = mathAbs(edgeB - gapB - (edgeA + gapA))
      if (index && chunkSize > viewSize + pixelTolerance) groups.push(rectB)
      if (isLast) groups.push(array.length)
      return groups
    }, []).map((currentSize, index, groups) => array.slice(Math.max(groups[index - 1] || 0), currentSize))
  }
  return { groupSlides: (array) => (isNumber(slidesToScroll) ? byNumber(array, slidesToScroll) : bySize(array)) }
}

function ScrollSnaps(axis, alignment, containerRect, slideRects, slidesToScroll) {
  const { startEdge, endEdge } = axis
  const { groupSlides } = slidesToScroll
  const alignments = groupSlides(slideRects)
    .map((rects) => arrayLast(rects)[endEdge] - rects[0][startEdge])
    .map(mathAbs)
    .map(alignment.measure)
  const snaps = slideRects.map((rect) => containerRect[startEdge] - rect[startEdge]).map((snap) => -mathAbs(snap))
  const snapsAligned = groupSlides(snaps).map((g) => g[0]).map((snap, index) => snap + alignments[index])
  return { snaps, snapsAligned }
}

function SlideRegistry(containSnaps, containScroll, scrollSnaps, scrollContainLimit, slidesToScroll, slideIndexes) {
  const { min, max } = scrollContainLimit
  const grouped = slidesToScroll.groupSlides(slideIndexes)
  if (scrollSnaps.length === 1) return [slideIndexes]
  if (!containSnaps || containScroll === "keepSnaps") return grouped
  return grouped.slice(min, max).map((group, index, groups) => {
    if (!index) return arrayFromNumber(arrayLast(groups[0]) + 1)
    if (arrayIsLastIndex(groups, index)) {
      return arrayFromNumber(arrayLastIndex(slideIndexes) - arrayLast(groups)[0] + 1, arrayLast(groups)[0])
    }
    return group
  })
}

function Translate(axis, element) {
  const translate = axis.scroll === "x" ? (n) => `translate3d(${n}px,0px,0px)` : (n) => `translate3d(0px,${n}px,0px)`
  let previousTarget = null
  return {
    to(target) {
      const newTarget = roundToTwoDecimals(axis.direction(target))
      if (newTarget === previousTarget) return
      element.style.transform = translate(newTarget)
      previousTarget = newTarget
    },
    clear() {
      element.style.transform = ""
      if (!element.getAttribute("style")) element.removeAttribute("style")
    }
  }
}

function SlideLooper(axis, viewSize, contentSize, slideSizes, slideSizesWithGaps, snaps, scrollSnaps, location, slides) {
  const roundingSafety = 0.5
  const ascItems = arrayKeys(slideSizesWithGaps)
  const descItems = arrayKeys(slideSizesWithGaps).reverse()
  const removeSlideSizes = (indexes, from) => indexes.reduce((a, i) => a - slideSizesWithGaps[i], from)
  const slidesInGap = (indexes, gap) => indexes.reduce((a, i) => (removeSlideSizes(a, gap) > 0 ? a.concat([i]) : a), [])
  const findSlideBounds = (offset) => snaps.map((snap, index) => ({
    start: snap - slideSizes[index] + roundingSafety + offset,
    end: snap + viewSize - roundingSafety + offset
  }))
  function findLoopPoints(indexes, offset, isEndEdge) {
    const slideBounds = findSlideBounds(offset)
    return indexes.map((index) => {
      const initial = isEndEdge ? 0 : -contentSize
      const altered = isEndEdge ? contentSize : 0
      const loopPoint = slideBounds[index][isEndEdge ? "end" : "start"]
      return {
        index, loopPoint, slideLocation: Vector1D(-1), translate: Translate(axis, slides[index]),
        target: () => (location.get() > loopPoint ? initial : altered)
      }
    })
  }
  const startPoints = findLoopPoints(slidesInGap(descItems, scrollSnaps[0]), contentSize, false)
  const endPoints = findLoopPoints(slidesInGap(ascItems, viewSize - scrollSnaps[0] - 1), -contentSize, true)
  const loopPoints = startPoints.concat(endPoints)
  return {
    canLoop: () => loopPoints.every(({ index }) => removeSlideSizes(ascItems.filter((i) => i !== index), viewSize) <= 0.1),
    clear: () => loopPoints.forEach((loopPoint) => loopPoint.translate.clear()),
    loop() {
      loopPoints.forEach(({ target, translate, slideLocation }) => {
        const shiftLocation = target()
        if (shiftLocation === slideLocation.get()) return
        translate.to(shiftLocation)
        slideLocation.set(shiftLocation)
      })
    }
  }
}

function DragTracker(axis, ownerWindow) {
  const logInterval = 170
  let startEvent
  let lastEvent
  const isMouse = (evt) => typeof ownerWindow.MouseEvent !== "undefined" && evt instanceof ownerWindow.MouseEvent
  function readPoint(evt, evtAxis) {
    const coord = `client${(evtAxis || axis.scroll) === "x" ? "X" : "Y"}`
    return (isMouse(evt) ? evt : evt.touches[0])[coord]
  }
  return {
    readPoint,
    pointerDown(evt) {
      startEvent = evt
      lastEvent = evt
      return readPoint(evt)
    },
    pointerMove(evt) {
      const diff = readPoint(evt) - readPoint(lastEvent)
      const expired = evt.timeStamp - startEvent.timeStamp > logInterval
      lastEvent = evt
      if (expired) startEvent = evt
      return diff
    },
    pointerUp(evt) {
      if (!startEvent || !lastEvent) return 0
      const diffDrag = readPoint(lastEvent) - readPoint(startEvent)
      const diffTime = evt.timeStamp - startEvent.timeStamp
      const expired = evt.timeStamp - lastEvent.timeStamp > logInterval
      const force = diffDrag / diffTime
      return diffTime && !expired && mathAbs(force) > 0.1 ? force : 0
    }
  }
}

function DragHandler(axis, rootNode, ownerDocument, ownerWindow, target, dragTracker, location, animation, scrollTo, scrollBody, scrollTarget, index, eventHandler, viewSize, dragFree, dragThreshold, skipSnaps, baseFriction, watchDrag) {
  const { cross: crossAxis, direction } = axis
  const focusNodes = ["INPUT", "SELECT", "TEXTAREA"]
  const nonPassiveEvent = { passive: false }
  const initEvents = EventStore()
  const dragEvents = EventStore()
  const goToNextThreshold = Limit(50, 225).constrain(viewSize * 0.2)
  const snapForceBoost = { mouse: 300, touch: 400 }
  const freeForceBoost = { mouse: 500, touch: 600 }
  const baseSpeed = dragFree ? 43 : 25
  let isMoving = false
  let startScroll = 0
  let startCross = 0
  let pointerIsDown = false
  let preventScroll = false
  let preventClick = false
  let isMouse = false

  const isMouseEvent = (evt) => typeof ownerWindow.MouseEvent !== "undefined" && evt instanceof ownerWindow.MouseEvent

  function addDragEvents() {
    const node = isMouse ? ownerDocument : rootNode
    dragEvents.add(node, "touchmove", move, nonPassiveEvent).add(node, "touchend", up)
      .add(node, "mousemove", move, nonPassiveEvent).add(node, "mouseup", up)
  }
  function allowedForce(force, targetChanged) {
    const next = index.add(mathSign(force) * -1)
    const baseForce = scrollTarget.byDistance(force, !dragFree).distance
    if (dragFree || mathAbs(force) < goToNextThreshold) return baseForce
    if (skipSnaps && targetChanged) return baseForce * 0.5
    return scrollTarget.byIndex(next.get(), 0).distance
  }
  function down(evt) {
    const isMouseEvt = isMouseEvent(evt)
    isMouse = isMouseEvt
    preventClick = dragFree && isMouseEvt && !evt.buttons && isMoving
    isMoving = deltaAbs(target.get(), location.get()) >= 2
    if (isMouseEvt && evt.button !== 0) return
    if (focusNodes.includes(evt.target.nodeName || "")) return
    pointerIsDown = true
    dragTracker.pointerDown(evt)
    scrollBody.useFriction(0).useDuration(0)
    target.set(location)
    addDragEvents()
    startScroll = dragTracker.readPoint(evt)
    startCross = dragTracker.readPoint(evt, crossAxis)
    eventHandler.emit("pointerDown")
  }
  function move(evt) {
    if (!isMouseEvent(evt) && evt.touches.length >= 2) return up(evt)
    const lastScroll = dragTracker.readPoint(evt)
    const lastCross = dragTracker.readPoint(evt, crossAxis)
    const diffScroll = deltaAbs(lastScroll, startScroll)
    const diffCross = deltaAbs(lastCross, startCross)
    if (!preventScroll && !isMouse) {
      if (!evt.cancelable) return up(evt)
      preventScroll = diffScroll > diffCross
      if (!preventScroll) return up(evt)
    }
    const diff = dragTracker.pointerMove(evt)
    if (diffScroll > dragThreshold) preventClick = true
    scrollBody.useFriction(0.3).useDuration(0.75)
    animation.start()
    target.add(direction(diff))
    evt.preventDefault()
  }
  function up(evt) {
    const currentLocation = scrollTarget.byDistance(0, false)
    const targetChanged = currentLocation.index !== index.get()
    const boost = (dragFree ? freeForceBoost : snapForceBoost)[isMouse ? "mouse" : "touch"]
    const rawForce = dragTracker.pointerUp(evt) * boost
    const force = allowedForce(direction(rawForce), targetChanged)
    const forceFactor = factorAbs(rawForce, force)
    const speed = baseSpeed - 10 * forceFactor
    const friction = baseFriction + forceFactor / 50
    preventScroll = false
    pointerIsDown = false
    dragEvents.clear()
    scrollBody.useDuration(speed).useFriction(friction)
    scrollTo.distance(force, !dragFree)
    isMouse = false
    eventHandler.emit("pointerUp")
  }
  function click(evt) {
    if (!preventClick) return
    evt.stopPropagation()
    evt.preventDefault()
    preventClick = false
  }
  return {
    init() {
      if (!watchDrag) return
      initEvents.add(rootNode, "dragstart", (evt) => evt.preventDefault(), nonPassiveEvent)
        .add(rootNode, "touchmove", () => undefined, nonPassiveEvent).add(rootNode, "touchend", () => undefined)
        .add(rootNode, "touchstart", down).add(rootNode, "mousedown", down)
        .add(rootNode, "touchcancel", up).add(rootNode, "contextmenu", up).add(rootNode, "click", click, true)
    },
    destroy() { initEvents.clear(); dragEvents.clear() },
    pointerDown: () => pointerIsDown
  }
}

function ResizeHandler(container, eventHandler, ownerWindow, slides, axis, watchResize) {
  const observeNodes = [container].concat(slides)
  let resizeObserver
  let containerSize
  let slideSizes = []
  let destroyed = false
  let frame = 0
  const readSize = (node) => axis.measureSize(measureNode(node))
  return {
    init(emblaApi) {
      if (!watchResize) return
      containerSize = readSize(container)
      slideSizes = slides.map(readSize)
      resizeObserver = new ResizeObserver((entries) => {
        for (const entry of entries) {
          if (destroyed) return
          const isContainer = entry.target === container
          const slideIndex = slides.indexOf(entry.target)
          const lastSize = isContainer ? containerSize : slideSizes[slideIndex]
          const newSize = readSize(isContainer ? container : slides[slideIndex])
          if (mathAbs(newSize - lastSize) >= 0.5) {
            emblaApi.reInit()
            eventHandler.emit("resize")
            break
          }
        }
      })
      frame = ownerWindow.requestAnimationFrame(() => observeNodes.forEach((node) => resizeObserver.observe(node)))
    },
    destroy() {
      destroyed = true
      ownerWindow.cancelAnimationFrame(frame)
      if (resizeObserver) resizeObserver.disconnect()
    }
  }
}

function SlidesHandler(container, eventHandler, watchSlides) {
  let mutationObserver
  let destroyed = false
  return {
    init(emblaApi) {
      if (!watchSlides) return
      mutationObserver = new MutationObserver((mutations) => {
        if (destroyed) return
        if (mutations.some((mutation) => mutation.type === "childList")) {
          emblaApi.reInit()
          eventHandler.emit("slidesChanged")
        }
      })
      mutationObserver.observe(container, { childList: true })
    },
    destroy() {
      if (mutationObserver) mutationObserver.disconnect()
      destroyed = true
    }
  }
}

function SlidesInView(container, slides, eventHandler, threshold) {
  const intersectionEntryMap = {}
  let inViewCache = null
  let notInViewCache = null
  let intersectionObserver
  let destroyed = false
  function createInViewList(inView) {
    return Object.keys(intersectionEntryMap).reduce((list, slideIndex) => {
      const index = parseInt(slideIndex)
      const { isIntersecting } = intersectionEntryMap[index]
      if ((inView && isIntersecting) || (!inView && !isIntersecting)) list.push(index)
      return list
    }, [])
  }
  return {
    init() {
      intersectionObserver = new IntersectionObserver((entries) => {
        if (destroyed) return
        entries.forEach((entry) => { intersectionEntryMap[slides.indexOf(entry.target)] = entry })
        inViewCache = null
        notInViewCache = null
        eventHandler.emit("slidesInView")
      }, { root: container.parentElement, threshold })
      slides.forEach((slide) => intersectionObserver.observe(slide))
    },
    destroy() {
      if (intersectionObserver) intersectionObserver.disconnect()
      destroyed = true
    },
    get(inView = true) {
      if (inView && inViewCache) return inViewCache
      if (!inView && notInViewCache) return notInViewCache
      const slideIndexes = createInViewList(inView)
      if (inView) inViewCache = slideIndexes
      else notInViewCache = slideIndexes
      return slideIndexes
    }
  }
}

function SlideFocus(root, slides, slideRegistry, scrollTo, scrollBody, eventStore, eventHandler, watchFocus) {
  const focusListenerOptions = { passive: true, capture: true }
  let lastTabPressTime = 0
  return {
    init() {
      if (!watchFocus) return
      function onFocus(index) {
        if (new Date().getTime() - lastTabPressTime > 10) return
        eventHandler.emit("slideFocusStart")
        root.scrollLeft = 0
        const group = slideRegistry.findIndex((slideGroup) => slideGroup.includes(index))
        if (!isNumber(group) || group < 0) return
        scrollBody.useDuration(0)
        scrollTo.index(group, 0)
        eventHandler.emit("slideFocus")
      }
      eventStore.add(root.ownerDocument, "keydown", (event) => { if (event.code === "Tab") lastTabPressTime = new Date().getTime() }, false)
      slides.forEach((slide, slideIndex) => eventStore.add(slide, "focus", () => onFocus(slideIndex), focusListenerOptions))
    }
  }
}

function EventHandler() {
  let listeners = {}
  let api
  const getListeners = (evt) => listeners[evt] || []
  const self = {
    init(emblaApi) { api = emblaApi },
    emit(evt) { getListeners(evt).forEach((cb) => cb(api, evt)); return self },
    on(evt, cb) { listeners[evt] = getListeners(evt).concat([cb]); return self },
    off(evt, cb) { listeners[evt] = getListeners(evt).filter((e) => e !== cb); return self },
    clear() { listeners = {} }
  }
  return self
}

function Engine(root, container, slides, ownerDocument, ownerWindow, options, eventHandler) {
  const {
    align, axis: scrollAxis, direction, startIndex, loop, duration, dragFree, dragThreshold, inViewThreshold,
    slidesToScroll: groupSlides, skipSnaps, containScroll, watchResize, watchSlides, watchDrag, watchFocus
  } = options
  const pixelTolerance = 2
  const containerRect = measureNode(container)
  const slideRects = slides.map(measureNode)
  const axis = Axis(scrollAxis, direction)
  const viewSize = axis.measureSize(containerRect)
  const alignment = Alignment(align, viewSize)
  const containSnaps = !loop && !!containScroll
  const readEdgeGap = loop || !!containScroll
  const { slideSizes, slideSizesWithGaps, startGap, endGap } = SlideSizes(axis, containerRect, slideRects, slides, readEdgeGap, ownerWindow)
  const slidesToScroll = SlidesToScroll(axis, viewSize, groupSlides, loop, containerRect, slideRects, startGap, endGap, pixelTolerance)
  const { snaps, snapsAligned } = ScrollSnaps(axis, alignment, containerRect, slideRects, slidesToScroll)
  const contentSize = -arrayLast(snaps) + arrayLast(slideSizesWithGaps)
  const { snapsContained, scrollContainLimit } = ScrollContain(viewSize, contentSize, snapsAligned, containScroll, pixelTolerance)
  const scrollSnaps = containSnaps ? snapsContained : snapsAligned
  const max = scrollSnaps[0]
  const limit = Limit(loop ? max - contentSize : arrayLast(scrollSnaps), max)
  const index = Counter(arrayLastIndex(scrollSnaps), startIndex, loop)
  const indexPrevious = index.clone()
  const slideIndexes = arrayKeys(slides)

  const friction = 0.68
  const startLocation = scrollSnaps[index.get()]
  const location = Vector1D(startLocation)
  const previousLocation = Vector1D(startLocation)
  const offsetLocation = Vector1D(startLocation)
  const target = Vector1D(startLocation)
  const translate = Translate(axis, container)

  const update = () => {
    if (!loop) engine.scrollBounds.constrain(engine.dragHandler.pointerDown())
    engine.scrollBody.seek()
  }
  const render = (alpha) => {
    const { scrollBody, scrollBounds, dragHandler } = engine
    const shouldSettle = scrollBody.settled()
    const withinBounds = !scrollBounds.shouldConstrain()
    const hasSettled = loop ? shouldSettle : shouldSettle && withinBounds
    const hasSettledAndIdle = hasSettled && !dragHandler.pointerDown()
    if (hasSettledAndIdle) engine.animation.stop()
    offsetLocation.set(location.get() * alpha + previousLocation.get() * (1 - alpha))
    if (loop) {
      engine.scrollLooper.loop(scrollBody.direction())
      engine.slideLooper.loop()
    }
    translate.to(offsetLocation.get())
    if (hasSettledAndIdle) eventHandler.emit("settle")
    if (!hasSettled) eventHandler.emit("scroll")
  }
  const animation = Animations(ownerDocument, ownerWindow, update, render)
  const scrollBody = ScrollBody(location, offsetLocation, previousLocation, target, duration, friction)
  const scrollTarget = ScrollTarget(loop, scrollSnaps, contentSize, limit, target)
  const scrollTo = ScrollTo(animation, index, indexPrevious, scrollBody, scrollTarget, target, eventHandler)
  const eventStore = EventStore()
  const slideRegistry = SlideRegistry(containSnaps, containScroll, scrollSnaps, scrollContainLimit, slidesToScroll, slideIndexes)
  const scrollProgress = (n) => { const current = n - limit.max; return limit.length ? current / -limit.length : 0 }

  const engine = {
    animation, axis, eventStore, index, indexPrevious, limit, location, offsetLocation, options, scrollBody, scrollSnaps,
    scrollTo, target, translate, slideIndexes, slideRegistry, scrollProgress,
    dragHandler: DragHandler(axis, root, ownerDocument, ownerWindow, target, DragTracker(axis, ownerWindow), location, animation, scrollTo, scrollBody, scrollTarget, index, eventHandler, viewSize, dragFree, dragThreshold, skipSnaps, friction, watchDrag),
    resizeHandler: ResizeHandler(container, eventHandler, ownerWindow, slides, axis, watchResize),
    scrollBounds: ScrollBounds(limit, offsetLocation, target, scrollBody, viewSize),
    scrollLooper: ScrollLooper(contentSize, limit, offsetLocation, [location, offsetLocation, previousLocation, target]),
    scrollSnapList: scrollSnaps.map(scrollProgress),
    slideLooper: SlideLooper(axis, viewSize, contentSize, slideSizes, slideSizesWithGaps, snaps, scrollSnaps, offsetLocation, slides),
    slideFocus: SlideFocus(root, slides, slideRegistry, scrollTo, scrollBody, eventStore, eventHandler, watchFocus),
    slidesHandler: SlidesHandler(container, eventHandler, watchSlides),
    slidesInView: SlidesInView(container, slides, eventHandler, inViewThreshold)
  }
  return engine
}

// embla's EmblaCarousel(root, options): the API object (embla:1586-1655) without internalEngine() and plugins().
function EmblaCarousel(root, userOptions) {
  const ownerDocument = root.ownerDocument
  const ownerWindow = ownerDocument.defaultView
  const mediaHandlers = EventStore()
  const eventHandler = EventHandler()
  const { on, off, emit } = eventHandler
  let destroyed = false
  let engine
  let optionsBase = objectsMergeDeep(DEFAULT_OPTIONS, {})
  let options
  let container
  let slides
  let initTimer = 0

  const optionsAtMedia = (opts) => {
    const matched = Object.keys(opts.breakpoints || {})
      .filter((media) => ownerWindow.matchMedia(media).matches)
      .map((media) => opts.breakpoints[media])
      .reduce((a, mediaOption) => objectsMergeDeep(a, mediaOption || {}), {})
    return objectsMergeDeep(opts, matched)
  }
  function storeElements() {
    const { container: userContainer, slides: userSlides } = options
    container = (isString(userContainer) ? root.querySelector(userContainer) : null) || root.children[0]
    slides = [].slice.call((isString(userSlides) ? container.querySelectorAll(userSlides) : null) || container.children)
  }
  function createEngine(opts) {
    const created = Engine(root, container, slides, ownerDocument, ownerWindow, opts, eventHandler)
    if (opts.loop && !created.slideLooper.canLoop()) return createEngine({ ...opts, loop: false })
    return created
  }
  function activate(withOptions) {
    if (destroyed) return
    optionsBase = objectsMergeDeep(optionsBase, withOptions || {})
    options = optionsAtMedia(optionsBase)
    storeElements()
    engine = createEngine(options)
    Object.keys(optionsBase.breakpoints || {}).map((query) => ownerWindow.matchMedia(query))
      .forEach((query) => mediaHandlers.add(query, "change", reActivate))
    if (!options.active) return
    engine.translate.to(engine.location.get())
    engine.animation.init()
    engine.slidesInView.init()
    engine.slideFocus.init(self)
    eventHandler.init(self)
    engine.resizeHandler.init(self)
    engine.slidesHandler.init(self)
    if (engine.options.loop) engine.slideLooper.loop()
    if (container.offsetParent && slides.length) engine.dragHandler.init(self)
  }
  function reActivate(withOptions) {
    const startIndex = selectedScrollSnap()
    deActivate()
    activate(objectsMergeDeep({ startIndex }, isObject(withOptions) ? withOptions : {}))
    eventHandler.emit("reInit")
  }
  function deActivate() {
    engine.dragHandler.destroy()
    engine.eventStore.clear()
    engine.translate.clear()
    engine.slideLooper.clear()
    engine.resizeHandler.destroy()
    engine.slidesHandler.destroy()
    engine.slidesInView.destroy()
    engine.animation.destroy()
    mediaHandlers.clear()
  }
  function destroy() {
    if (destroyed) return
    destroyed = true
    ownerWindow.clearTimeout(initTimer)
    mediaHandlers.clear()
    deActivate()
    eventHandler.emit("destroy")
    eventHandler.clear()
  }
  function scrollTo(index, jump, direction) {
    if (!options.active || destroyed) return
    engine.scrollBody.useBaseFriction().useDuration(jump === true ? 0 : options.duration)
    engine.scrollTo.index(index, direction || 0)
  }
  const selectedScrollSnap = () => engine.index.get()
  const self = {
    canScrollNext: () => engine.index.add(1).get() !== selectedScrollSnap(),
    canScrollPrev: () => engine.index.add(-1).get() !== selectedScrollSnap(),
    containerNode: () => container,
    destroy,
    off,
    on,
    emit,
    previousScrollSnap: () => engine.indexPrevious.get(),
    reInit: reActivate,
    rootNode: () => root,
    scrollNext: (jump) => scrollTo(engine.index.add(1).get(), jump, -1),
    scrollPrev: (jump) => scrollTo(engine.index.add(-1).get(), jump, 1),
    scrollProgress: () => engine.scrollProgress(engine.offsetLocation.get()),
    scrollSnapList: () => engine.scrollSnapList,
    scrollTo,
    selectedScrollSnap,
    slideNodes: () => slides,
    slidesInView: () => engine.slidesInView.get(),
    slidesNotInView: () => engine.slidesInView.get(false)
  }
  activate(userOptions)
  initTimer = ownerWindow.setTimeout(() => eventHandler.emit("init"), 0)
  return self
}

export default class extends Controller {
  static targets = ["viewport", "previous", "next"]
  static values = {
    orientation: { type: String, default: "horizontal" },
    opts: { type: Object, default: {} }
  }

  api = null
  built = null
  cache = null

  connect() {
    this.#create()
    // The engine writes inline transforms and the buttons' `disabled`; Turbo's snapshot must hold the server markup, so the
    // engine is destroyed on turbo:before-cache and built again once the snapshot is taken.
    this.cache = turboCacheRestore({ teardown: () => this.#snapshot(), restore: () => this.#create() })
  }

  disconnect() {
    this.cache?.release()
    this.cache = null
    this.#destroy()
  }

  orientationValueChanged() {
    this.#rebuild()
  }

  optsValueChanged() {
    this.#rebuild()
  }

  scrollPrev() {
    this.api?.scrollPrev()
  }

  scrollNext() {
    this.api?.scrollNext()
  }

  // shadcn's onKeyDownCapture (tsx:78-89): both orientations use the horizontal arrows.
  keydown(event) {
    if (event.key === "ArrowLeft") {
      event.preventDefault()
      this.scrollPrev()
    } else if (event.key === "ArrowRight") {
      event.preventDefault()
      this.scrollNext()
    }
  }

  #rebuild() {
    if (!this.api || this.built === this.#signature()) return
    this.#destroy()
    this.#create()
  }

  #create() {
    if (!this.hasViewportTarget || !this.viewportTarget.children[0]) {
      this.built = null
      return
    }
    this.built = this.#signature()
    const options = { ...this.optsValue, axis: this.orientationValue === "horizontal" ? "x" : "y" }
    this.api = EmblaCarousel(this.viewportTarget, options)
    this.api
      .on("select", () => {
        this.#reconcileButtons()
        this.dispatch("select", { detail: { index: this.api.selectedScrollSnap(), previousIndex: this.api.previousScrollSnap() } })
      })
      .on("reInit", () => {
        this.#reconcileButtons()
        this.dispatch("reinit", { detail: { index: this.api.selectedScrollSnap() } })
      })
      .on("settle", () => this.dispatch("settle", { detail: { index: this.api.selectedScrollSnap() } }))
    this.dispatch("api", { detail: { api: this.api } })
    this.#reconcileButtons()
  }

  #signature() {
    return JSON.stringify([this.optsValue, this.orientationValue])
  }

  #destroy() {
    this.api?.destroy()
    this.api = null
  }

  // The engine is gone and the server markup is back: the buttons start disabled again (a caller's `disabled` is left alone).
  #snapshot() {
    this.#destroy()
    const disable = (button) => { if (!this.#locked(button)) button.disabled = true }
    this.previousTargets.forEach(disable)
    this.nextTargets.forEach(disable)
  }

  // Buttons whose `disabled` the caller set (data-chadcn--carousel-locked) are never touched (React spreads props last).
  // Without an engine (an empty viewport) both start disabled, as the server rendered them.
  #reconcileButtons() {
    const { api } = this
    this.previousTargets.forEach((button) => { if (!this.#locked(button)) button.disabled = api ? !api.canScrollPrev() : true })
    this.nextTargets.forEach((button) => { if (!this.#locked(button)) button.disabled = api ? !api.canScrollNext() : true })
  }

  #locked(button) {
    return button.hasAttribute("data-chadcn--carousel-locked")
  }
}
