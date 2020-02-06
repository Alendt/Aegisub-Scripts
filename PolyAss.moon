script_name = "PolyAss"
script_description = "Performs boolean operations on polygons"
script_author = "Alen"
script_version = "1.1"

[[SOME NOTES:

To use this script you need a shape and a clip on a line.
For example:
{\an7\blur1\bord0\shad0\fscx100\fscy100\pos(0,0)\p1\clip(m 818 120 l 1378 94 1556 250 1248 592 722 430)}m 324 334 l 676 234 1028 326 1158 586 900 782 376 746 288 680
That's for the boolean operations.

There are also 2 more function for now.
Text to shape: pretty explicative by the name
Inner Shadow: create an inner shadow just like the ones you can do in illustrator
If you're creating a inner shadow from a text, check the option "Convert Text" that you find inside the GUI.

More will come when I'll be sure everything works as intended.

I'm not a programmer, I do this only as a hobby and for fun. Don't get mad if the code is bad :)
The code is basically this https://github.com/voidqk/polybooljs rewrote in lua the best way I could.
If you find bugs or the results you are getting are not the correct, please report them.
Also be carefull on what you do. Expect the script to be VERY SLOW if you use complex shape.
The code for the aegisub part is definitely improvable. I wrote it quickly just to get this out and give it to some people for feedback.
If you want to use "text to shape" or "inner shadow" don't use fscx/y, use only fs for now.
I couldn't understand how to center the shape properly using yutils data if there are these 2 tags.
If for whatever reason you want to contact me more directly, you can do it on discord Alen#4976]]

Yutils = include("Yutils.lua")

operate = (poly1, poly2, selector) ->
	seg1 = PolyBool.segments(poly1)
	seg2 = PolyBool.segments(poly2)
	comb = PolyBool.combine(seg1, seg2)
	seg3 = selector(comb)

	return PolyBool.polygon(seg3)

export LinkedList = {
	create: (my) ->
		my = {
			root: {root: true, next: nil},

			exists: (node) ->
				if node == nil or node == my.root
					return false
				return true,

			isEmpty: ->
				return my.root.next == nil,

			getHead: ->
				return my.root.next,

			insertBefore: (node, check) ->
				last = my.root
				here = my.root.next
				while here != nil
					if check(here)
						node.prev = here.prev
						node.next = here
						here.prev.next = node
						here.prev = node
						return
					last = here
					here = here.next
				last.next = node
				node.prev = last
				node.next = nil,

			findTransition: (check) ->
				prev = my.root
				here = my.root.next
				while here != nil
					if check(here)
						break
					prev = here
					here = here.next
				return {
					before: prev == my.root and nil or prev,
					after: here,
					insert: (node) ->
						node.prev = prev
						node.next = here
						prev.next = node
						if here != nil
							here.prev = node
						return node
				}
		}

		return my,

	node: (data) ->
		data.prev = nil
		data.next = nil
		data.remove = ->
			data.prev.next = data.next
			if data.next
				data.next.prev = data.prev
			data.prev = nil
			data.next = nil

		return data
}

Intersecter = (selfIntersection, eps) ->
	segmentNew = (start, fine) ->
		return {
			id: nil,
			start: start,
			fine: fine,
			myFill: {
				above: nil,
				below: nil
			},
			otherFill: nil
		}

	segmentCopy = (start, fine, seg) ->
		return {
			id: nil,
			start: start,
			fine: fine,
			myFill: {
				above: seg.myFill.above,
				below: seg.myFill.below
			},
			otherFill: nil
		}

	event_root = LinkedList.create!

	eventCompare = (p1_isStart, p1_1, p1_2, p2_isStart, p2_1, p2_2) ->
		comp = Epsilon.pointsCompare(p1_1, p2_1)
		if comp != 0
			return comp

		if Epsilon.pointsSame(p1_2, p2_2)
			return 0

		if p1_isStart != p2_isStart
			if p1_isStart return 1 else return -1

		local a, b, c
		if p2_isStart then a = p2_1 else a = p2_2
		if p2_isStart then b = p2_2 else b = p2_1
		if Epsilon.pointAboveOrOnLine(p1_2, a, b) then c = 1 else c = -1

		return c

	eventAdd = (ev, other_pt) ->
		func = (here) ->
			comp = eventCompare(ev.isStart, ev.pt, other_pt, here.isStart, here.pt, here.other.pt)
			return comp < 0

		event_root.insertBefore(ev, func)

	eventAddSegmentStart = (seg, primary) ->
		ev_start = LinkedList.node({
			isStart: true,
			pt: seg.start,
			seg: seg,
			primary: primary,
			other: nil,
			status: nil
		})
		eventAdd(ev_start, seg.fine)
		return ev_start

	eventAddSegmentEnd = (ev_start, seg, primary) ->
		ev_end = LinkedList.node({
			isStart: false,
			pt: seg.fine,
			seg: seg,
			primary: primary,
			other: ev_start,
			status: nil
		})
		ev_start.other = ev_end
		eventAdd(ev_end, ev_start.pt)

	eventAddSegment = (seg, primary) ->
		ev_start = eventAddSegmentStart(seg, primary)
		eventAddSegmentEnd(ev_start, seg, primary)
		return ev_start

	eventUpdateEnd = (ev, fine) ->
		ev.other.remove()
		ev.seg.fine = fine
		ev.other.pt = fine
		eventAdd(ev.other, ev.pt)

	eventDivide = (ev, pt) ->
		ns = segmentCopy(pt, ev.seg.fine, ev.seg)
		eventUpdateEnd(ev, pt)
		return eventAddSegment(ns, ev.primary)

	calculate = (primaryPolyInverted, secondaryPolyInverted) ->

		status_root = LinkedList.create!

		statusCompare = (ev1, ev2) ->
			a1 = ev1.seg.start
			a2 = ev1.seg.fine
			b1 = ev2.seg.start
			b2 = ev2.seg.fine

			if Epsilon.pointsCollinear(a1, b1, b2)
				if Epsilon.pointsCollinear(a2, b1, b2)
					return 1
				if Epsilon.pointAboveOrOnLine(a2, b1, b2) return 1 else return -1

			if Epsilon.pointAboveOrOnLine(a1, b1, b2) return 1 else return -1

		statusFindSurrounding = (ev) ->
			func = (here) ->
				comp = statusCompare(ev, here.ev)
				return comp > 0

			return status_root.findTransition(func)

		checkIntersection = (ev1, ev2) ->
			seg1 = ev1.seg
			seg2 = ev2.seg
			a1 = seg1.start
			a2 = seg1.fine
			b1 = seg2.start
			b2 = seg2.fine
			
			i = Epsilon.linesIntersect(a1, a2, b1, b2)
			
			if i == false
				if not Epsilon.pointsCollinear(a1, a2, b1)
					return false

				if Epsilon.pointsSame(a1, b2) or Epsilon.pointsSame(a2, b1)
					return false

				a1_equ_b1 = Epsilon.pointsSame(a1, b1)
				a2_equ_b2 = Epsilon.pointsSame(a2, b2)

				if a1_equ_b1 and a2_equ_b2
					return ev2

				a1_between = not a1_equ_b1 and Epsilon.pointBetween(a1, b1, b2)
				a2_between = not a2_equ_b2 and Epsilon.pointBetween(a2, b1, b2)

				if a1_equ_b1
					if a2_between
						eventDivide(ev2, a2)
					else
						eventDivide(ev1, b2)
					return ev2

				elseif a1_between
					if not a2_equ_b2
						if a2_between
							eventDivide(ev2, a2)
						else
							eventDivide(ev1, b2)

					eventDivide(ev2, a1)

			else
				if i.alongA == 0
					if i.alongB == -1
						eventDivide(ev1, b1)
					elseif i.alongB == 0
						eventDivide(ev1, i.pt)
					elseif i.alongB == 1
						eventDivide(ev1, b2)

				if i.alongB == 0
					if i.alongA == -1
						eventDivide(ev2, a1)
					elseif i.alongA == 0
						eventDivide(ev2, i.pt)
					elseif i.alongA == 1
						eventDivide(ev2, a2)

			return false

		--main
		segments = {}

		while not event_root.isEmpty()
			ev = event_root.getHead!

			if ev.isStart
				surrounding = statusFindSurrounding(ev)

				local above, below
				if surrounding.before then above = surrounding.before.ev else above = nil
				if surrounding.after then below = surrounding.after.ev else below = nil

				checkBothIntersections = ->
					if above
						eve = checkIntersection(ev, above)
						if eve
							return eve

					if below
						return checkIntersection(ev, below)

					return false

				eve = checkBothIntersections()

				if eve
					if selfIntersection
						local toggle
						if ev.seg.myFill.below == nil
							toggle = true
						else
							toggle = ev.seg.myFill.above != ev.seg.myFill.below

						if toggle
							eve.seg.myFill.above = not eve.seg.myFill.above
					else
						eve.seg.otherFill = ev.seg.myFill

					ev.other.remove()
					ev.remove()

				if event_root.getHead() != ev
					continue

				if selfIntersection
					local toggle
					if ev.seg.myFill.below == nil
						toggle = true
					else
						toggle = ev.seg.myFill.above != ev.seg.myFill.below
					if not below
						ev.seg.myFill.below = primaryPolyInverted

					else
						ev.seg.myFill.below = below.seg.myFill.above

					if toggle
						ev.seg.myFill.above = not ev.seg.myFill.below
					else
						ev.seg.myFill.above = ev.seg.myFill.below

				else
					if ev.seg.otherFill == nil
						local inside
						if not below
							if ev.primary then inside = secondaryPolyInverted else inside = primaryPolyInverted

						else
							if ev.primary == below.primary
								inside = below.seg.otherFill.above
							else
								inside = below.seg.myFill.above

						ev.seg.otherFill = {
							above: inside,
							below: inside
						}

				ev.other.status = surrounding.insert(LinkedList.node({ ev: ev }))

			else
				st = ev.status

				if st == nil
					aegisub.log("PolyBool: Zero-length segment detected; your epsilon is probably too small or too large\n")
					break

				if status_root.exists(st.prev) and status_root.exists(st.next)
					checkIntersection(st.prev.ev, st.next.ev)

				st.remove()

				if not ev.primary
					s = ev.seg.myFill
					ev.seg.myFill = ev.seg.otherFill
					ev.seg.otherFill = s
				
				table.insert(segments, ev.seg)

			event_root.getHead().remove()

		return segments

	if not selfIntersection
		return {
			calculate: (segments1, inverted1, segments2, inverted2) ->
				func = (seg) ->
					eventAddSegment(segmentCopy(seg.start, seg.fine, seg), true)
			
				for each in *segments1 do
					func(each)


				func2 = (seg) ->
					eventAddSegment(segmentCopy(seg.start, seg.fine, seg), false)

				for each in *segments2 do
					func2(each)

				return calculate(inverted1, inverted2)
		}

	return {
		addRegion: (region) ->
			pt1 = nil
			pt2 = region[#region]
			for i = 1, #region
				pt1 = pt2
				pt2 = region[i]

				forward = Epsilon.pointsCompare(pt1, pt2)
				if forward != 0
					eventAddSegment(segmentNew(forward < 0 and pt1 or pt2, forward < 0 and pt2 or pt1), true),

		calculate: (inverted) ->
			return calculate(inverted, false)
	}

export eps = 0.0000000001
export Epsilon = {
	epsilon: (v) ->
		if type(v) == "number"
			eps = v
		return eps,

	pointAboveOrOnLine: (pt, left, right) ->
		Ax = left[1]
		Ay = left[2]
		Bx = right[1]
		By = right[2]
		Cx = pt[1]
		Cy = pt[2]
		return (Bx - Ax) * (Cy - Ay) - (By - Ay) * (Cx - Ax) >= -eps,

	pointBetween: (p, left, right) ->
		d_py_ly = p[2] - left[2]
		d_rx_lx = right[1] - left[1]
		d_px_lx = p[1] - left[1]
		d_ry_ly = right[2] - left[2]

		dot = d_px_lx * d_rx_lx + d_py_ly * d_ry_ly
		if dot < eps
			return false
		
		sqlen = d_rx_lx * d_rx_lx + d_ry_ly * d_ry_ly
		if (dot - sqlen > -eps)
			return false

		return true,

	pointsSameX: (p1, p2) ->
		return math.abs(p1[1] - p2[1]) < eps,

	pointsSameY: (p1, p2) ->
		return math.abs(p1[2] - p2[2]) < eps,

	pointsSame: (p1, p2) ->
		return Epsilon.pointsSameX(p1, p2) and Epsilon.pointsSameY(p1, p2),

	pointsCompare: (p1, p2) ->
		if Epsilon.pointsSameX(p1, p2)
			if Epsilon.pointsSameY(p1, p2)
				return 0
			elseif p1[2] < p2[2]
				return -1
			elseif not (p1[2] < p2[2])
				return 1

		if p1[1] < p2[1]
			return -1
		else
			return 1,

	pointsCollinear: (pt1, pt2, pt3) ->
		dx1 = pt1[1] - pt2[1]
		dy1 = pt1[2] - pt2[2]
		dx2 = pt2[1] - pt3[1]
		dy2 = pt2[2] - pt3[2]
		return math.abs(dx1 * dy2 - dx2 * dy1) < eps,

	linesIntersect: (a0, a1, b0, b1) ->
		adx = a1[1] - a0[1]
		ady = a1[2] - a0[2]
		bdx = b1[1] - b0[1]
		bdy = b1[2] - b0[2]

		axb = adx * bdy - ady * bdx
		if math.abs(axb) < eps
			return false

		dx = a0[1] - b0[1]
		dy = a0[2] - b0[2]

		A = (bdx * dy - bdy * dx) / axb
		B = (adx * dy - ady * dx) / axb

		ret = {
			alongA: 0,
			alongB: 0,
			pt: {
				a0[1] + A * adx,
				a0[2] + A * ady
			}
		}

		if A <= -eps
			ret.alongA = -2
		elseif A < eps
			ret.alongA = -1
		elseif A - 1 <= -eps
			ret.alongA = 0
		elseif A - 1 < eps
			ret.alongA = 1
		else
			ret.alongA = 2

		if B <= -eps
			ret.alongB = -2
		elseif B < eps
			ret.alongB = -1
		elseif B - 1 <= -eps
			ret.alongB = 0
		elseif B - 1 < eps
			ret.alongB = 1
		else
			ret.alongB = 2

		return ret,

	pointInsideRegion: (pt, region) ->
		x = pt[1]
		y = pt[2]
		last_x = region[#region][1]
		last_y = region[#region][2]
		inside = false
		for i = 1, #region
			curr_x = region[i][1]
			curr_y = region[i][2]

			if (curr_y - y > eps) != (last_y - y > eps) and (last_x - curr_x) * (y - curr_y) / (last_y - curr_y) + curr_x - x > eps
				inside = not inside

			last_x = curr_x
			last_y = curr_y

		return inside
}

select = (segments, selection) ->
	result = {}

	func = (seg) ->
		local n, n2, n3, n4
		if seg.myFill.above then n = 8 else n = 0
		if seg.myFill.below then n2 = 4 else n2 = 0
		if seg.otherFill != nil and seg.otherFill.above then n3 = 2 else n3 = 0
		if seg.otherFill != nil and seg.otherFill.below then n4 = 1 else n4 = 0
		
		index = n + n2 + n3 + n4 + 1

		if selection[index] != 0
			table.insert(result, {
				id: nil
				start: seg.start,
				fine: seg.fine,
				myFill: {
					above: selection[index] == 1,
					below: selection[index] == 2
				},
				otherFill: nil
			})

	for each in *segments do func(each)

	return result

SegmentSelector = {
	union: (segments) ->
		return select(segments, {
			0, 2, 1, 0,
			2, 2, 0, 0,
			1, 0, 1, 0,
			0, 0, 0, 0
		}),

	intersect: (segments) ->
		return select(segments, {
			0, 0, 0, 0,
			0, 2, 0, 2,
			0, 0, 1, 1,
			0, 2, 1, 0	
		}),

	difference: (segments) ->
		return select(segments, {
			0, 0, 0, 0,
			2, 0, 2, 0,
			1, 1, 0, 0,
			0, 1, 2, 0
		}),

	differenceRev: (segments) ->
		return select(segments, {
			0, 2, 1, 0,
			0, 0, 1, 1,
			0, 2, 0, 2,
			0, 0, 0, 0
		}),
	xor: (segments) ->
		return select(segments, {
			0, 2, 1, 0,
			2, 0, 0, 1,
			1, 0, 0, 2,
			0, 1, 2, 0
		})
}

SegmentChainer = (segments, eps) ->
	chains = {}
	regions = {}

	func = (seg) ->
		pt1 = seg.start
		pt2 = seg.fine

		if eps.pointsSame(pt1, pt2)
			aegisub.log("PolyBool: Warning: Zero-length segment detected; your epsilon is probably too small or too large\n")
			return

		first_match = {
			index: 1,
			matches_head: false,
			matches_pt1: false
		}
		second_match = {
			index: 1,
			matches_head: false,
			matches_pt1: false
		}
		next_match = first_match

		setMatch = (index, matches_head, matches_pt1) ->
			next_match.index = index
			next_match.matches_head = matches_head
			next_match.matches_pt1 = matches_pt1

			if next_match == first_match
				next_match = second_match
				return false

			next_match = nil
			return true

		for i = 1, #chains
			chain = chains[i]
			head = chain[1]
			head2 = chain[2]
			tail = chain[#chain]
			tail2 = chain[#chain - 1]

			if eps.pointsSame(head, pt1)
				if setMatch(i, true, true)
					break

			elseif eps.pointsSame(head, pt2)
				if setMatch(i, true, false)
					break

			elseif eps.pointsSame(tail, pt1)
				if setMatch(i, false, true)
					break

			elseif eps.pointsSame(tail, pt2)
				if setMatch(i, false, false)
					break

		if next_match == first_match
			table.insert(chains, {pt1, pt2})
			return

		if next_match == second_match
			index = first_match.index
			
			local pt
			if first_match.matches_pt1 then pt = pt2 else pt = pt1

			addToHead = first_match.matches_head

			chain = chains[index]

			local grow, grow2, oppo, oppo2
			if addToHead then grow = chain[1] else grow = chain[#chain]
			if addToHead then grow2 = chain[2] else grow2 = chain[#chain - 1]
			if addToHead then oppo = chain[#chain] else oppo = chain[1]
			if addToHead then oppo2 = chain[#chain - 1] else oppo2 = chain[2]

			if eps.pointsCollinear(grow2, grow, pt)
				if addToHead
					table.remove(chain, 1)
				else
					table.remove(chain, #chain)

				grow = grow2

			if eps.pointsSame(oppo, pt)
				table.remove(chains, index)

				if eps.pointsCollinear(oppo2, oppo, grow)
					if addToHead
						table.remove(chain, #chain)
					else
						table.remove(chain, 1)

				table.insert(regions, chain)
				return

			if addToHead
				table.insert(chain, 1, pt)
			else
				table.insert(chain, pt)

			return

		reverseChain = (index) ->
			tempChain = {}
			for i = 1, #chains[index]
				table.insert(tempChain, 1, chains[index][i])

			chains[index] = tempChain

		appendChain = (index1, index2) ->
			chain1 = chains[index1]
			chain2 = chains[index2]
			tail = chain1[#chain1]
			tail2 = chain1[#chain1 - 1]
			head = chain2[1]
			head2 = chain2[2]

			if eps.pointsCollinear(tail2, tail, head)
				table.remove(chain1, #chain1)
				tail = tail2

			if eps.pointsCollinear(tail, head, head2)
				table.remove(chain2, 1)

			for i = 1, #chain2
				table.insert(chain1, chain2[i])

			table.remove(chains, index2)

		F = first_match.index
		S = second_match.index

		reverseF = #chains[F] < #chains[S]

		if first_match.matches_head
			if second_match.matches_head
				if reverseF
					reverseChain(F)
					appendChain(F, S)
				else
					reverseChain(S)
					appendChain(S, F)
			else
				appendChain(S, F)
		else
			if second_match.matches_head
				appendChain(F, S)
			else
				if reverseF
					reverseChain(F)
					appendChain(S, F)
				else
					reverseChain(S)
					appendChain(F, S)

	for each in *segments do func(each)
	return regions

export PolyBool = {
	segments: (poly) ->
		i = Intersecter(true, Epsilon)
		for each in *poly.regions do
			i.addRegion(each)

		return {
			segments: i.calculate(poly.inverted),
			inverted: poly.inverted
		},

	combine: (segments1, segments2) ->
		i3 = Intersecter(false, Epsilon)
		return {
			combined: i3.calculate(segments1.segments, segments1.inverted, segments2.segments, segments2.inverted),
			inverted1: segments1.inverted,
			inverted2: segments2.inverted
		},

	selectUnion: (combined) ->
		return {
			segments: SegmentSelector.union(combined.combined),
			inverted: combined.inverted1 or combined.inverted2
		},

	selectIntersect: (combined) ->
		return {
			segments: SegmentSelector.intersect(combined.combined),
			inverted: combined.inverted1 and combined.inverted2
		},

	selectDifference: (combined) ->
		return {
			segments: SegmentSelector.difference(combined.combined),
			inverted: combined.inverted1 and not combined.inverted2
		},

	selectDifferenceRev: (combined) ->
		return {
			segments: SegmentSelector.differenceRev(combined.combined),
			inverted: not combined.inverted1 and combined.inverted2
		},

	selectXor: (combined) ->
		return {
			segments: SegmentSelector.xor(combined.combined),
			inverted: combined.inverted1 != combined.inverted2
		},

	polygon: (segments) ->
		return {
			regions: SegmentChainer(segments.segments, Epsilon),
			inverted: segments.inverted
		},

	union: (poly1, poly2) ->
		return operate(poly1, poly2, PolyBool.selectUnion),

	intersect: (poly1, poly2) ->
		return operate(poly1, poly2, PolyBool.selectIntersect),

	difference: (poly1, poly2) ->
		return operate(poly1, poly2, PolyBool.selectDifference),
	
	differenceRev: (poly1, poly2) ->
		return operate(poly1, poly2, PolyBool.selectDifferenceRev),
	
	xor: (poly1, poly2) ->
		return operate(poly1, poly2, PolyBool.selectXor)
}

round = (val, n) ->
	if n
		return math.floor((val * 10^n) + 0.5) / (10^n)
	else
		return math.floor(val+0.5)

newPolygon = (clip, inverted) ->
	clip = Yutils.shape.flatten(clip)
	coord = {}
	part = {}

	for i in clip\gmatch("m ([^m]+)")
		table.insert(part, i)

	for i = 1, #part
		for x, y in part[i]\gmatch("([-%d.]+).([-%d.]+)")
			if coord[i] == nil then coord[i] = {}
			table.insert(coord[i], {tonumber(x), tonumber(y)})

	return {
		regions: coord,
		inverted: inverted
	}

build = (p, toClip) ->
	shape = ""
	for k = 1, #p.regions
		for i = 1, #p.regions[k]
			if i == 1
				shape = shape .. "m " .. round(p.regions[k][i][1], 3) .. " " .. round(p.regions[k][i][2], 3) .. " l "
			else
				shape = shape .. round(p.regions[k][i][1], 3) .. " " .. round(p.regions[k][i][2], 3) .. " "
	
	if toClip
		shape = "\\clip(" .. shape .. ")"

	return shape

GUI = {
	main: {
		{
			class: "checkbox", label: "Keep original line(do not use)", name: "original",
			value: false,
			x: 0, y: 0, width: 1, height: 1
		},
		{
			class: "label", label: "Horizontal:",
			x: 0, y: 1, width: 1, height: 1
		},
		{
			class: "floatedit", name: "horizontal",
			x: 0, y: 2, width: 1, height: 1
		},
		{
			class: "label", label: "Vertical:",
			x: 0, y: 3, width: 1, height: 1
		},
		{
			class: "floatedit", name: "vertical",
			x: 0, y: 4, width: 1, height: 1
		},
		{
			class: "checkbox", label: "Text to shape", name: "convertText",
			value: false,
			x: 0, y: 5, width: 1, height: 1
		}
	}
}

PolyAss = (sub, sel) ->
	currLine = 0
	for si, li in ipairs(sel)
		currLine = 0
		line = sub[li]
		clip = line.text\match("\\clip%b()")
		pol = line.text\match("}([^{]+)")
		poly1 = newPolygon(clip, false)
		poly2 = newPolygon(pol, false)
		test = PolyBool.union(poly1, poly2)
		newline = line
		newline.text = "{\\an7\\blur1\\bord0\\shad0\\fscx100\\fscy100\\pos(0,0)\\p1}" .. build(test, false)
		sub.insert(li + 1 + currLine, newline)
		currLine += 1

PolyAss2 = (sub, sel) ->
	currLine = 0
	for si, li in ipairs(sel)
		line = sub[li]
		clip = line.text\match("\\clip%b()")
		pol = line.text\match("}([^{]+)")
		poly1 = newPolygon(clip, false)
		poly2 = newPolygon(pol, false)
		test = PolyBool.intersect(poly1, poly2)
		newline = line
		newline.text = "{\\an7\\blur1\\bord0\\shad0\\fscx100\\fscy100\\pos(0,0)\\p1}" .. build(test, false)
		sub.insert(li + 1 + currLine, newline)
		currLine += 1

PolyAss3 = (sub, sel) ->
	currLine = 0
	for si, li in ipairs(sel)
		line = sub[li]
		clip = line.text\match("\\clip%b()")
		pol = line.text\match("}([^{]+)")
		poly1 = newPolygon(clip, false)
		poly2 = newPolygon(pol, false)
		test = PolyBool.differenceRev(poly1, poly2)
		newline = line
		newline.text = "{\\an7\\blur1\\bord0\\shad0\\fscx100\\fscy100\\pos(0,0)\\p1}" .. build(test, false)
		sub.insert(li + 1 + currLine, newline)
		currLine += 1

PolyAss4 = (sub, sel) ->
	currLine = 0
	for si, li in ipairs(sel)
		line = sub[li]
		clip = line.text\match("\\clip%b()")
		pol = line.text\match("}([^{]+)")
		poly1 = newPolygon(clip, false)
		poly2 = newPolygon(pol, false)
		test = PolyBool.difference(poly1, poly2)
		newline = line
		newline.text = "{\\an7\\blur1\\bord0\\shad0\\fscx100\\fscy100\\pos(0,0)\\p1}" .. build(test, false)
		sub.insert(li + 1 + currLine, newline)
		currLine += 1

PolyAss5 = (sub, sel) ->
	currLine = 0
	for si, li in ipairs(sel)
		line = sub[li]
		clip = line.text\match("\\clip%b()")
		pol = line.text\match("}([^{]+)")
		poly1 = newPolygon(clip, false)
		poly2 = newPolygon(pol, false)
		test = PolyBool.xor(poly1, poly2)
		newline = line
		newline.text = "{\\an7\\blur1\\bord0\\shad0\\fscx100\\fscy100\\pos(0,0)\\p1}" .. build(test, false)
		sub.insert(li + 1 + currLine, newline)
		currLine += 1

TextToShape = (sub, sel) ->
	currLine = 0
	for si, li in ipairs(sel)
		line = sub[li]
		local pol
		posx, posy = line.text\match("^{[^}]-\\pos%(([-%d.]+).([-%d.]+)%)")
		if posx == nil then posx, posy = 0, 0
		text2 = line.text
		text2 = text2\gsub("%b{}","")
		family = "Arial"
		bold = false
		italic = false
		underline = false
		strikeout = false
		size = 50
		xscale = 100
		yscale = 100
		hspace = 0

		if line.text\match("\\fn([^\\]+)") then family = line.text\match("\\fn([^\\]+)")
		if line.text\match("\\b1") then bold = true
		if line.text\match("\\i1") then italic = true
		if line.text\match("\\u1") then underline = true
		if line.text\match("\\s1") then strikeout = true
		if line.text\match("^{[^}]-\\fs([%d%.%-]+)") then size = line.text\match("^{[^}]-\\fs([%d%.%-]+)")
		if line.text\match("^{[^}]-\\fscx([%d%.%-]+)") then xscale = line.text\match("^{[^}]-\\fscx([%d%.%-]+)")
		if line.text\match("^{[^}]-\\fscy([%d%.%-]+)") then yscale = line.text\match("^{[^}]-\\fscy([%d%.%-]+)")
		if line.text\match("^{[^}]-\\fsp([%d%.%-]+)") then hspace = line.text\match("^{[^}]-\\fsp([%d%.%-]+)")
		pol = Yutils.decode.create_font(family, bold, italic, underline, strikeout, tonumber(size), 1, 1, tonumber(hspace)).text_to_shape(text2)
		extents = Yutils.decode.create_font(family, bold, italic, underline, strikeout, tonumber(size), 1, 1, tonumber(hspace)).text_extents(text2)
		pol = Yutils.shape.move(pol, -(tonumber(extents.width / 2)), -(tonumber(extents.height / 2)))
		newline = line
		newline.text = "{\\an7\\blur0\\bord0\\shad0\\fscx100\\fscy100\\pos(" .. posx .. "," .. posy .. ")\\p1}" .. pol
		sub.insert(li + 1 + currLine, newline)
		currLine += 1

InnerShadow = (sub, sel) ->
	ok, config = aegisub.dialog.display(GUI.main, {"Run"})
	if ok
		currLine = 0
		for si, li in ipairs(sel)
			line = sub[li]
			
			local pol
			posx, posy = line.text\match("^{[^}]-\\pos%(([-%d.]+).([-%d.]+)%)")
			if posx == nil then posx, posy = 0, 0

			if config.convertText
				text2 = line.text
				text2 = text2\gsub("%b{}","")
				family = "Arial"
				bold = false
				italic = false
				underline = false
				strikeout = false
				size = 50
				xscale = 100
				yscale = 100
				hspace = 0

				if line.text\match("\\fn([^\\]+)") then family = line.text\match("\\fn([^\\]+)")
				if line.text\match("\\b1") then bold = true
				if line.text\match("\\i1") then italic = true
				if line.text\match("\\u1") then underline = true
				if line.text\match("\\s1") then strikeout = true
				if line.text\match("^{[^}]-\\fs([%d%.%-]+)") then size = line.text\match("^{[^}]-\\fs([%d%.%-]+)")
				if line.text\match("^{[^}]-\\fscx([%d%.%-]+)") then xscale = line.text\match("^{[^}]-\\fscx([%d%.%-]+)")
				if line.text\match("^{[^}]-\\fscy([%d%.%-]+)") then yscale = line.text\match("^{[^}]-\\fscy([%d%.%-]+)")
				if line.text\match("^{[^}]-\\fsp([%d%.%-]+)") then hspace = line.text\match("^{[^}]-\\fsp([%d%.%-]+)")
				pol = Yutils.decode.create_font(family, bold, italic, underline, strikeout, tonumber(size), 1, 1, tonumber(hspace)).text_to_shape(text2)
				extents = Yutils.decode.create_font(family, bold, italic, underline, strikeout, tonumber(size), 1, 1, tonumber(hspace)).text_extents(text2)
				pol = Yutils.shape.move(pol, -(tonumber(extents.width / 2)), -(tonumber(extents.height / 2)))

			else
				pol = line.text\match("}([^{]+)")

			poly1 = newPolygon(pol, false)
			
			poly2 = newPolygon(Yutils.shape.move(pol, config.horizontal, config.vertical), false)
			test = PolyBool.differenceRev(poly2, poly1)
			newline = line
			newline.text = "{\\an7\\blur0\\bord0\\shad0\\fscx100\\fscy100\\pos(" .. posx .. "," .. posy .. ")\\p1}" .. build(test, false)
			sub.insert(li + 1 + currLine, newline)
			currLine += 1

aegisub.register_macro("PolyAss/Operations/Union", "Union", PolyAss)
aegisub.register_macro("PolyAss/Operations/Intersect", "Intersect", PolyAss2)
aegisub.register_macro("PolyAss/Operations/DifferenceRev", "DifferenceRev", PolyAss3)
aegisub.register_macro("PolyAss/Operations/Difference", "Difference", PolyAss4)
aegisub.register_macro("PolyAss/Operations/Xor", "Xor", PolyAss5)
aegisub.register_macro("PolyAss/Text to shape", "TextToShape", TextToShape)
aegisub.register_macro("PolyAss/Inner shadow", "InnerShadow", InnerShadow)
