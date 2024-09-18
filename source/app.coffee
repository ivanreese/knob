TAU = 2*Math.PI
DEG = 180/Math.PI
RAD = Math.PI/180

Array.prototype.sum = ()->
	return 0 unless this.length > 0
	this.reduce (a,b)->
		a+b

Array.prototype.average = ()->
	return 0 unless this.length > 0
	total = this.reduce (a,b)->
		a+b
	total/this.length

Array.prototype.mapPairs = (call)->
	return [] unless this.length > 1
	values = []
	this.reduce (a,b)->
		values.push(call(a,b))
		b
	values

@Angle =
	wrap: (ang, bias)->
		while bias - ang > +Math.PI then ang += TAU
		while bias - ang < -Math.PI then ang -= TAU
		ang

@Vec =
	diff: (a,b)->
		x: b.x - a.x
		y: b.y - a.y

	angle: (a, b)->
		p = Vec.diff(a,b)
		Math.atan2(p.y, p.x)

	distance: (a,b)->
		p = Vec.diff(a,b)
		Math.sqrt(p.x*p.x + p.y*p.y)

	pathLength: (arr)->
		arr.mapPairs(Vec.distance).sum()

	lerp: (a, b, t)->
		d = Math.max(0, Math.min(1, t))
		{
			x: a.x*(1-d) + b.x*d
			y: a.y*(1-d) + b.y*d
		}

newPoint = ()-> {x: 0, y: 0, a: 0}

start = 				newPoint()
last = 					newPoint()
current = 			newPoint()
center = 				newPoint()
recentCenter = 	newPoint()
accumulated = 	newPoint()
recentMin = 		newPoint()
recentMax =			newPoint()
recentSize = 		newPoint()
activeCenter = 	newPoint()
usage = 				newPoint()
delta = 				newPoint()

centerTransitionTime = 100
recentAngleBasis = 0
recent = [{x:0,y:0}]
# recent = [{x:282,y:204},{x:282,y:205},{x:283,y:205},{x:284,y:206},{x:285,y:207},{x:287,y:208},{x:288,y:209},{x:289,y:209},{x:289,y:210},{x:291,y:210},{x:291,y:211},{x:292,y:212},{x:293,y:213},{x:295,y:214},{x:295,y:216},{x:296,y:216},{x:298,y:218},{x:299,y:219},{x:300,y:220},{x:302,y:221},{x:303,y:222},{x:305,y:222},{x:305,y:224},{x:308,y:225},{x:310,y:226},{x:311,y:229},{x:313,y:230},{x:316,y:231},{x:317,y:233},{x:320,y:236},{x:323,y:237},{x:325,y:239},{x:328,y:242},{x:331,y:242},{x:331,y:244},{x:334,y:244},{x:334,y:245},{x:335,y:246},{x:336,y:247},{x:337,y:247},{x:339,y:249},{x:341,y:250},{x:343,y:251},{x:346,y:251},{x:348,y:252},{x:348,y:253},{x:348,y:254},{x:350,y:254},{x:351,y:254},{x:351,y:256},{x:353,y:256}]
dragging = false
computedValue = 0
squareness = 0
time = 0
hud =
	left: 30
	labelLeft: 60
	top: 40
	space: 50
	pos: 0
	nextPos: ()-> hud.pos++
	resetPos: ()-> hud.pos = 0
canvas = null
g = null

# BEGIN
$ ()->
	canvas = document.getElementById("canvas")
	g = canvas.getContext("2d")
	resize()


# RESIZE
resize = ()->
	canvas.width = $(window).width()   # * window.devicePixelRatio
	canvas.height = $(window).height() # * window.devicePixelRatio
	center =
		x:canvas.width/2
		y:canvas.height/2
	draw()
$(window).on "resize", resize

# LOGIC
update = (p)->
	return unless Vec.distance(p, last) > 0
	current = p

	recent.unshift(current)
	recent.pop() while Vec.pathLength(recent) > 2*TAU * Vec.distance(activeCenter, current) and recent.length > 2

	recentMin = recent.reduce (a,b)-> { x: Math.min(a.x, b.x), y: Math.min(a.y, b.y) }
	recentMax = recent.reduce (a,b)-> { x: Math.max(a.x, b.x), y: Math.max(a.y, b.y) }
	recentSize = Vec.diff(recentMin, recentMax)
	recentCenter =
		x: (recentMin.x + recentMax.x)/2
		y: (recentMin.y + recentMax.y)/2

	time++
	activeCenter = Vec.lerp(center, recentCenter, time/centerTransitionTime)

	delta =
		x: (current.x - start.x)
		y: (current.y - start.y)
		a: angleToActiveCenter(current)

	accumulated.x += current.x - last.x
	accumulated.y += current.y - last.y
	accumulated.a += Angle.wrap(current.a - last.a, 0)

	computedValue += computedValueIncrement()

	squareness = computeSquareness(recentSize)

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
		Angle.wrap(current.a - last.a, 0) / TAU
	else if recentSize.x > recentSize.y
		usage.x++
		(current.x - last.x) / (TAU * 20)
	else
		usage.y++
		-(current.y - last.y) / (TAU * 20)


# EVENTS

$(window).mousedown (e)->
	dragging = true
	time = 0
	recent = []
	usage = newPoint()
	activeCenter = center
	start = last = computePosition(e.pageX, e.pageY)

$(window).mouseup (e)->
	dragging = false

$(window).mousemove (e)->
	if dragging
		update(computePosition(e.pageX, e.pageY))


# MMMMMMMATH

angleToActiveCenter = (p)->
	d = Vec.diff(activeCenter, p)
	Math.atan2(d.y, d.x)

computePosition = (x, y)->
	p = {x:x, y:y}
	p.a = angleToActiveCenter(p)
	p

computeSquareness = (vec)->
	1-Math.abs(Math.log(vec.x/vec.y))


# DRAWING
prepareToDraw = ()->
	hud.resetPos()
	g.clearRect(0,0,canvas.width,canvas.height)
	g.font = "20px sans-serif"
	g.beginPath()

drawPoint = (p, style, size = 5)->
	g.beginPath()
	g.fillStyle = style
	g.arc(p.x, p.y, size, 0, TAU)
	g.fill()

drawRecent = ()->
	g.beginPath()
	g.strokeStyle = "#FFF"
	g.moveTo(current.x, current.y)
	g.lineTo(p.x,p.y) for p in recent
	g.stroke()

drawRecentBounds = ()->

	g.beginPath()
	g.strokeStyle = "#F00"
	g.strokeRect(recentMin.x, recentMin.y, recentSize.x, recentSize.y)

drawRecentAngle = ()->
	g.beginPath()
	g.strokeStyle = "#07F"

	angle = recent.mapPairs(Vec.angle).map((ang)-> Angle.wrap(ang, recentAngleBasis)).average()
	recentAngleBasis = angle # save for the future

	sx = current.x
	sy = current.y
	dx = sx + Math.cos(angle) * 50
	dy = sy + Math.sin(angle) * 50
	g.moveTo(sx, sy)
	g.lineTo(dx, dy)
	g.stroke()

drawComputedValue = ()->
	angle = computedValue * TAU
	loops = Math.floor(Math.abs(angle) / TAU)
	isNeg = angle < 0

	g.fillStyle = if isNeg then "rgba(255,0,0,0.2)" else "rgba(0,0,255,0.2)"

	r = 20

	for i in [0..loops]
		g.beginPath()
		g.arc(center.x, center.y, r * i, 0, TAU)
		g.lineTo(center.x, center.y)
		g.fill()

	offset = -TAU/4
	angle %= TAU

	g.beginPath()
	g.arc(center.x, center.y, r * (loops+1), offset, angle+offset, isNeg)
	g.lineTo(center.x, center.y)
	g.fill()

hudValue = (value, label)->
	pos = hud.nextPos()
	g.fillStyle = "#F70"
	g.fillText(Math.round(value*100)/100, hud.left - 20, hud.top + hud.space * pos)
	g.fillStyle = "#FFF"
	g.fillText(label, hud.left + hud.labelLeft, hud.top + hud.space * pos)

hudPoint = (point, label, aScale = 1)->
	hudValue(point.x, "X " + label)
	hudValue(point.y, "Y " + label)
	hudValue(point.a * aScale, "A " + label)

draw = ()->
	prepareToDraw()

	drawComputedValue()
	drawPoint(center, "#0F9")
	# drawPoint(start, "#F70")
	drawPoint(activeCenter, "#F00", 2)
	drawRecent()
	drawRecentBounds()

	# hudValue(computedValue, "Computed Value")
	# hudValue(squareness, "Squareness")
	# hudPoint(accumulated, "Accumulated", DEG)
	# hudPoint(usage, "Usage")
	# hudPoint(delta, "Delta", DEG)
