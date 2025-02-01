TAU = Math.PI * 2

sum = (arr)-> if arr.length is 0 then 0 else arr.reduce (a, b)-> a+b
average = (arr)-> if arr.length is 0 then 0 else sum(arr) / arr.length
mapPairs = (arr, cb) -> arr.slice(1).map (v, i) -> cb arr[i], v

wrapAngle = (angle) -> (((angle + Math.PI) % TAU) + TAU) % TAU - Math.PI

Vec =
	diff: (a, b)-> x: b.x - a.x, y: b.y - a.y
	angle: (a, b)->
		p = Vec.diff a, b
		Math.atan2 p.y, p.x
	hypot: ({x, y})-> Math.hypot x, y
	distance: (a, b)-> Vec.hypot Vec.diff a, b
	pathLength: (arr)-> sum mapPairs arr, Vec.distance
	lerp: (a, b, t)->
		t = Math.max 0, Math.min 1, t
		x: a.x * (1-t) + b.x * t
		y: a.y * (1-t) + b.y * t

newPoint = (x = 0, y = 0, a = 0)-> { x, y, a }

last = 					newPoint()
current = 			newPoint()
center = 				newPoint()
recentSize = 		newPoint()
activeCenter = 	newPoint()
usage = 				newPoint()

centerTransitionTime = 100
recent = [{x:0, y:0}]
computedValue = 0
squareness = 0
time = 0

# LOGIC
update = (p)->
	return unless Vec.distance(p, last) > 0
	current = p

	recent.unshift(current)

	# we want roughly 2 full loops around the mouse
	radius = Vec.distance(activeCenter, current)
	desiredLength = TAU * radius * 2
	recent.pop() while Vec.pathLength(recent) > desiredLength and recent.length > 2

	recentMin = recent.reduce (a, b)-> { x: Math.min(a.x, b.x), y: Math.min(a.y, b.y) }
	recentMax = recent.reduce (a, b)-> { x: Math.max(a.x, b.x), y: Math.max(a.y, b.y) }
	recentSize = Vec.diff(recentMin, recentMax)
	recentCenter =
		x: (recentMin.x + recentMax.x)/2
		y: (recentMin.y + recentMax.y)/2

	time++
	activeCenter = Vec.lerp center, recentCenter, time / centerTransitionTime

	computedValue += computedValueIncrement()

	squareness = 1 - Math.abs Math.log recentSize.x / recentSize.y

	last = current

	draw()

computedValueIncrement = ()->
	# If usage.x and usage.y are both 0, then useAngularInput will be unfairly biased toward true.
	# This can happen even when dragging straight if you get 1 usage.a right off the bat.
	# So, cardinal bias gives us some "free" initial x/y usage.
	cardinalBias = 10

	preferAngularInput = usage.a > (cardinalBias + usage.x + usage.y) * 2

	useAngularInput = squareness > 0 or preferAngularInput

	if useAngularInput
		usage.a++
		wrapAngle(current.a - last.a) / TAU
	else if recentSize.x > recentSize.y
		usage.x++
		(current.x - last.x) / (TAU * 20)
	else
		usage.y++
		-(current.y - last.y) / (TAU * 20)

# DRAWING

canvas = document.querySelector "canvas"
g = canvas.getContext "2d"

resize = ()->
	dpr = window.devicePixelRatio
	canvas.width = window.innerWidth   * dpr
	canvas.height = window.innerHeight * dpr
	g.scale dpr, dpr
	center =
		x:window.innerWidth/2
		y:window.innerHeight/2
	draw()

draw = ()->
	g.clearRect(0,0,canvas.width,canvas.height)
	drawPoint(center, "#fff")
	drawComputedValue()

drawPoint = (p, style, size = 5)->
	g.beginPath()
	g.fillStyle = style
	g.arc(p.x, p.y, size, 0, TAU)
	g.fill()

drawComputedValue = ()->
	angle = computedValue * TAU
	loops = Math.floor(Math.abs(angle) / TAU)
	isNeg = angle < 0

	g.fillStyle = if isNeg then "#f004" else "#00f4"

	r = 20

	# Draw a circle for each full turn
	for i in [0..loops]
		g.beginPath()
		g.arc(center.x, center.y, r * i, 0, TAU)
		g.lineTo(center.x, center.y)
		g.fill()

	# Draw a wedge for the progress through the final turn
	offset = -TAU/4
	angle %= TAU
	g.beginPath()
	g.arc(center.x, center.y, r * (loops+1), offset, angle+offset, isNeg)
	g.lineTo(center.x, center.y)
	g.fill()

# BEGIN

window.onpointerdown = (e)->
	time = 0
	recent = []
	usage = newPoint()
	activeCenter = center
	last = newPoint e.pageX, e.pageY
	last.a = Vec.angle activeCenter, last
	window.onpointermove = move
	window.onpointerup = stop

move = (e)->
	newPos = newPoint e.pageX, e.pageY
	newPos.a = Vec.angle activeCenter, newPos
	update newPos

stop = (e)->
	window.onpointermove = null
	window.onpointerup = null

window.onresize = resize

resize() # Also calls draw()
