export script_name = "Shapery"
export script_description = "Try to emulate the most used tools of Illustrator."
export script_author = "Alen"
export script_version = "1.2.1"
export script_namespace = "alen.Shapery"

Helptext = "====== Comment and credits ======
I'm not a programmer, most of the code is just a 1:1 copy from somewhere rewrote in moonscript.
I do this only as a hobby and for fun. Don't get mad if the code is bad :)

This automation is based on this library http://www.angusj.com/delphi/clipper.php.
I also used the javascript version as reference. You can find it here https://sourceforge.net/projects/jsclipper/

If you find bugs or the results you are getting are wrong, please report them. Advices and ideas are welcome. (Check the TO-DO list before maybe)
Be carefull with what you do. If you are doing something with complex shapes, you should save your script before running this automation.
If you want to contact me for advices or anything, you can do it on discord Alen#4976

====== Pathfinder ======
Given 2 polygons in the form of shape and clip, the automation will perform the selected operation between them.

-Union: the result will be an union between the shape and the clip.
-Difference: the result will be the the shape minus the clip.
-Intersect: the result will be a polygon composed by the part where both shape and clip are present.
-XOR: the opposite of intersect

It is possible to chose the filling rule of the 2 polygons (shape and clip).
Look it up online for the difference or just use NonZero, which is the one libass and vsfilter uses.

The checkbox 'Multiline' allow for more lines to be selected, the script will use the first selected line as a Subject and all the others as Clip.

====== Offsetting ======
Inflating and deflating polygons.
The angles can have 3 style: miter, round and square.
The arc tolerance define the precision a curve will have if the style Round is used.

====== Others ======
-Text to shape
Explicative by the name. The result will maintain the same appearance the text had with all tags except for \\fax and \\fay.
If you need these tags you should add them after the text is converted.

-Inner Shadow
Creates an inner shadow effect. One of the first thing you learn in Illustrator.
This function only works with shapes. If you want to use this on a text, you have to convert it to a shape before.

-Move shape
Since other (unanimated's) automations removes the decimals, I've added this as well.
Moves the shape by the specified amount.

-Center Shape
Move the shape so that it has its center at 0,0.

====== Gradient ======
This will allow you to create a gradient in a similar way you can do in Illustrator.
In order to use this you need to have at least 2 lines (or more depending on how many colors you need) and a clip in the first line of 2 points.
The two points will be used as the gradient start and ending position, the clip will also be used as the direction.
After that you select all the lines you created, open the script, set the step size and press 'Gradient'.
There should also be an option to let the user chose the overlap size, but from the test I've done the best results are obtainable by using the step size as overlap size as well, so I decided to remove it.

====== Macros ======
These are some function you can use without opening the GUI.
-Clip To Shape

-Shape To Clip

-Expand
Works only with shapes.
Remove certain tags that change the aspect of the shape while preserving the appearance.
Such tags are \\fscx, \\fscy, \\fax, \\fay, \\frx, \\fry, \\frz and \\org.
Sometimes if there's extreme perspective this might produce wrong result, I'll come back to this later.

====== TO-DO ======
1. Simplify polygons by recreating bezier curve.
The automation don't work with bezier, so all the path are flattened before being passed to the automation.
By my understanding this only affect the filesize and not the renderer (at least libass), so it's fine to not have this for now.
2. Shape generator.
Just like the most used font 'split spludge', 'grain', etc...
3. Improve the 'Inner Shadow' function.
It has a problem that i don't know how to explain. It's easy to fix anyway."

haveDepCtrl, DependencyControl, depctrl = pcall(require, "l0.DependencyControl")
if haveDepCtrl
	depctrl = DependencyControl{feed: "https://raw.githubusercontent.com/Alendt/Aegisub-Scripts/master/DependencyControl.json"}

Yutils = include("Yutils.lua")
require 'karaskel'
logger = DependencyControl.logger

ClipperLib = {
	use_lines: true,

	Clear: ->
		return {},

	PI: 3.141592653589793,

	PI2: 2 * 3.141592653589793,
	
	ClipType: {
		ctIntersection: 0,
		ctUnion: 1,
		ctDifference: 2,
		ctXor: 3
	},

	PolyType: {
		ptSubject: 0,
		ptClip: 1
	},

	PolyFillType: {
		pftEvenOdd: 0,
		pftNonZero: 1,
		pftPositive: 2,
		pftNegative: 3
	},

	JoinType: {
		jtSquare: 0,
		jtRound: 1,
		jtMiter: 2
	},

	EndType: {
		etOpenSquare: 0,
		etOpenRound: 1,
		etOpenButt: 2,
		etClosedLine: 3,
		etClosedPolygon: 4
	},

	EdgeSide: {
		esLeft: 0,
		esRight: 1
	},

	Direction: {
		dRightToLeft: 0,
		dLeftToRight: 1
	},

	Point: {},

	ClipperBase: {
		horizontal: -9007199254740992,
		Skip: -2,
		Unassigned: -1,
		tolerance: 1E-20,
		loRange: 47453132,
		hiRange: 4503599627370495
	},

	Clipper: {
		ioReverseSolution: 1,
		ioStrictlySimple: 2,
		ioPreserveCollinear: 4,
		NodeType: {
			ntAny: 0,
			ntOpen: 1,
			ntClosed: 2
		}
	},

	rDecimals: 2,

	MyIntersectNodeSort: {},

	ClipperOffset: {
		two_pi: 6.28318530717959,
		def_arc_tolerance: 0.25
	}
}

ClipperLib.Error = (message) ->
	aegisub.log(message)
	aegisub.cancel!

BitXOR = (a, b) ->
	p, c = 1, 0
	while a>0 and b>0
		ra, rb = a%2, b%2
		if ra != rb then c = c+p
		a, b, p = (a-ra)/2, (b-rb)/2, p*2

	if a<b then a = b 
	while a>0
		ra = a%2
		if ra>0 then c = c+p
		a, p = (a-ra)/2, p*2

	return c

Round = (val, dec) ->
	if dec == nil then dec = ClipperLib.rDecimals
	return math.floor((val * 10^dec) + 0.5) / (10^dec)

class Path
	new: =>
		self = {}

class PolyNode
	new: =>
		@m_Parent = nil
		@m_polygon = Path!
		@m_Index = 0
		@m_jointype = 0
		@m_endtype = 0
		@m_Childs = {}
		@IsOpen = false

	m_Childs: {} --?
	
	IsHoleNode: =>
		result = true
		node = @m_Parent
		while (node != nil)
			result = not result
			node = node.m_Parent
		return result

	ChildCount: =>
		return #@m_Childs

	Contour: =>
		return @m_polygon

	AddChild: (Child) =>
		cnt = #@m_Childs
		table.insert(@m_Childs, Child)
		Child.m_Parent = self
		Child.m_Index = cnt

	GetNext: =>
		if #@m_Childs > 1
			return @m_Childs[1]
		else
			return @GetNextSiblingUp!

	GetNextSiblingUp: =>
		if @m_Parent == nil
			return nil
		elseif @m_Index == #@m_Parent.m_Childs
			return @m_Parent\GetNextSiblingUp!
		else
			return @m_Parent.m_Childs[@m_Index + 1]

	Childs: =>
		return @m_Childs

	Parent: =>
		return @m_Parent

	IsHole: =>
		return @IsHoleNode!

class Point
	new: (...) =>
		a = {...}
		@X = 0
		@Y = 0

		if #a == 1
			@X = a[1].X
			@Y = a[1].Y
		elseif #a == 2
			@X = a[1]
			@Y = a[2]
		else
			@X = 0
			@Y = 0

ClipperLib.Point.op_Equality = (a, b) ->
	return a.X == b.X and a.Y == b.Y

ClipperLib.Point.op_Inequality = (a, b) ->
	return a.X != b.X or a.Y != b.Y

class Rect
	new: (...) =>
		a = {...}
		alen = #a
		if (alen == 4)
			@left = a[1]
			@top = a[2]
			@right = a[3]
			@bottom = a[4]
		elseif (alen == 1)
			ir = a[1]
			@left = ir.left
			@top = ir.top
			@right = ir.right
			@bottom = ir.bottom
		else
			@left = 0
			@top = 0
			@right = 0
			@bottom = 0

class TEdge
	new: =>
		@Bot = Point!
		@Curr = Point! --current (updated for every new scanbeam)
		@Top = Point!
		@Delta = Point!
		@Dx = 0
		@PolyTyp = ClipperLib.PolyType.ptSubject
		@Side = ClipperLib.EdgeSide.esLeft -- side only refers to current side of solution poly
		@WindDelta = 0 -- 1 or -1 depending on winding direction
		@WindCnt = 0
		@WindCnt2 = 0 -- winding count of the opposite polytype
		@OutIdx = 0
		@Next = nil
		@Prev = nil
		@NextInLML = nil
		@NextInAEL = nil
		@PrevInAEL = nil
		@NextInSEL = nil
		@PrevInSEL = nil

class IntersectNode
	new: =>
		@Edge1 = nil
		@Edge2 = nil
		@Pt = Point!

class LocalMinima
	new: =>
		@Y = 0
		@LeftBound = nil
		@RightBound = nil
		@Next = nil

class Scanbeam
	new: =>
		@Y = 0
		@Next = nil

class Maxima
	new: =>
		@X = 0
		@Next = nil
		@Prev = nil

class OutRec
	new: =>
		@Idx = 0
		@IsHole = false
		@IsOpen = false
		@FirstLeft = nil
		@Pts = nil
		@BottomPt = nil
		@PolyNode = nil

class OutPt
	new: =>
		@Idx = 0
		@Pt = Point!
		@Next = nil
		@Prev = nil

class Join
	new: =>
		@OutPt1 = nil
		@OutPt2 = nil
		@OffPt = Point!

ClipperLib.ClipperBase.SlopesEqual = (...) ->
	a = {...}

	if #a == 2 -- ClipperLib.ClipperBase.SlopesEqual3 = (e1, e2) ->
		e1, e2 = a[1], a[2]
		return ((e1.Delta.Y) * (e2.Delta.X)) == ((e1.Delta.X) * (e2.Delta.Y))

	elseif #a == 3 -- ClipperLib.ClipperBase.SlopesEqual4 = (pt1, pt2, pt3) ->
		pt1, pt2, pt3 = a[1], a[2], a[3]
		return ((pt1.Y - pt2.Y) * (pt2.X - pt3.X)) - ((pt1.X - pt2.X) * (pt2.Y - pt3.Y)) == 0

	elseif #a == 4 -- ClipperLib.ClipperBase.SlopesEqual5 = (pt1, pt2, pt3, pt4) ->
		pt1, pt2, pt3, pt4 = a[1], a[2], a[3], a[4]
		return ((pt1.Y - pt2.Y) * (pt3.X - pt4.X)) - ((pt1.X - pt2.X) * (pt3.Y - pt4.Y)) == 0

ClipperLib.ClipperBase.near_zero = (val) ->
	return (val > -ClipperLib.ClipperBase.tolerance) and (val < ClipperLib.ClipperBase.tolerance)

ClipperLib.ClipperBase.IsHorizontal = (e) ->
	return e.Delta.Y == 0

class ClipperBase
	m_MinimaList: nil
	m_CurrentLM: nil
	m_edges: {}
	m_HasOpenPaths: false
	PreserveCollinear: false
	m_Scanbeam: nil
	m_PolyOuts: nil
	m_ActiveEdges: nil

	PointIsVertex: (pt, pp) =>
		pp2 = pp
		while true do
			if (ClipperLib.Point.op_Equality(pp2.Pt, pt))
				return true
			pp2 = pp2.Next

			if pp2 == pp
				break

		return false

	Clear: =>
		@DisposeLocalMinimaList!
		for i = 1, #@m_edges
			for j = 1, #@m_edges[i]
				@m_edges[i][j] = nil
			@m_edges[i] = ClipperLib.Clear!
		@m_edges = ClipperLib.Clear!
		@m_HasOpenPaths = false

	DisposeLocalMinimaList: =>
		while (@m_MinimaList != nil)
			tmpLm = @m_MinimaList.Next
			@m_MinimaList = nil
			@m_MinimaList = tmpLm

		@m_CurrentLM = nil

	InitEdge: (e, eNext, ePrev, pt) =>
		e.Next = eNext
		e.Prev = ePrev
		e.Curr.X = pt.X
		e.Curr.Y = pt.Y
		e.OutIdx = -1

	InitEdge2: (e, polyType) =>
		if (e.Curr.Y >= e.Next.Curr.Y)
			e.Bot.X = e.Curr.X
			e.Bot.Y = e.Curr.Y

			e.Top.X = e.Next.Curr.X
			e.Top.Y = e.Next.Curr.Y
		else
			e.Top.X = e.Curr.X
			e.Top.Y = e.Curr.Y

			e.Bot.X = e.Next.Curr.X
			e.Bot.Y = e.Next.Curr.Y

		@SetDx(e)
		e.PolyTyp = polyType

	FindNextLocMin: (E) =>
		E2 = nil
		while true do
			while (ClipperLib.Point.op_Inequality(E.Bot, E.Prev.Bot) or ClipperLib.Point.op_Equality(E.Curr, E.Top))
				E = E.Next
			
			if (E.Dx != ClipperLib.ClipperBase.horizontal and E.Prev.Dx != ClipperLib.ClipperBase.horizontal)
				break

			while (E.Prev.Dx == ClipperLib.ClipperBase.horizontal)
				E = E.Prev
			E2 = E

			while (E.Dx == ClipperLib.ClipperBase.horizontal)
				E = E.Next

			if (E.Top.Y == E.Prev.Bot.Y)
				continue

			--ie just an intermediate horz.
			if (E2.Prev.Bot.X < E.Bot.X)
				E = E2

			break

		return E

	ProcessBound: (E, LeftBoundIsForward) =>
		EStart = nil
		Result = E
		Horz = nil

		if (Result.OutIdx == ClipperLib.ClipperBase.Skip)
			--check if there are edges beyond the skip edge in the bound and if so
			--create another LocMin and calling ProcessBound once more ...
			E = Result
			if (LeftBoundIsForward)
				while (E.Top.Y == E.Next.Bot.Y)
					E = E.Next
				while (E != Result and E.Dx == ClipperLib.ClipperBase.horizontal)
					E = E.Prev
			else
				while (E.Top.Y == E.Prev.Bot.Y)
					E = E.Prev
				while (E != Result and E.Dx == ClipperLib.ClipperBase.horizontal)
					E = E.Next

			if (E == Result)
				if (LeftBoundIsForward)
					Result = E.Next
				else
					Result = E.Prev

			else
				--there are more edges in the bound beyond result starting with E
				if (LeftBoundIsForward)
					E = Result.Next
				else
					E = Result.Prev

				locMin = LocalMinima!
				locMin.Next = nil
				locMin.Y = E.Bot.Y
				locMin.LeftBound = nil
				locMin.RightBound = E
				E.WindDelta = 0
				Result = @ProcessBound(E, LeftBoundIsForward)
				@InsertLocalMinima(locMin)

			return Result

		if (E.Dx == ClipperLib.ClipperBase.horizontal)
			--We need to be careful with open paths because this may not be a
			--true local minima (ie E may be following a skip edge).
			--Also, consecutive horz. edges may start heading left before going right.
			if (LeftBoundIsForward)
				EStart = E.Prev
			else
				EStart = E.Next

			if (EStart.Dx == ClipperLib.ClipperBase.horizontal) --ie an adjoining horizontal skip edge
				if (EStart.Bot.X != E.Bot.X and EStart.Top.X != E.Bot.X)
					@ReverseHorizontal(E)

			elseif (EStart.Bot.X != E.Bot.X)
				@ReverseHorizontal(E)

		EStart = E
		if (LeftBoundIsForward)
			while (Result.Top.Y == Result.Next.Bot.Y and Result.Next.OutIdx != ClipperLib.ClipperBase.Skip)
				Result = Result.Next
			if (Result.Dx == ClipperLib.ClipperBase.horizontal and Result.Next.OutIdx != ClipperLib.ClipperBase.Skip)
				--nb: at the top of a bound, horizontals are added to the bound
				--only when the preceding edge attaches to the horizontal's left vertex
				--unless a Skip edge is encountered when that becomes the top divide
				Horz = Result
				while (Horz.Prev.Dx == ClipperLib.ClipperBase.horizontal)
					Horz = Horz.Prev
				if (Horz.Prev.Top.X > Result.Next.Top.X)
					Result = Horz.Prev

			while (E != Result)
				E.NextInLML = E.Next
				if (E.Dx == ClipperLib.ClipperBase.horizontal and E != EStart and E.Bot.X != E.Prev.Top.X)
					@ReverseHorizontal(E)
				E = E.Next

			if (E.Dx == ClipperLib.ClipperBase.horizontal and E != EStart and E.Bot.X != E.Prev.Top.X)
				@ReverseHorizontal(E)
			Result = Result.Next
			--move to the edge just beyond current bound

		else
			while (Result.Top.Y == Result.Prev.Bot.Y and Result.Prev.OutIdx != ClipperLib.ClipperBase.Skip)
				Result = Result.Prev
			
			if (Result.Dx == ClipperLib.ClipperBase.horizontal and Result.Prev.OutIdx != ClipperLib.ClipperBase.Skip)
				Horz = Result
				while (Horz.Next.Dx == ClipperLib.ClipperBase.horizontal)
					Horz = Horz.Next
				if (Horz.Next.Top.X == Result.Prev.Top.X or Horz.Next.Top.X > Result.Prev.Top.X)
					Result = Horz.Next

			while (E != Result)
				E.NextInLML = E.Prev
				if (E.Dx == ClipperLib.ClipperBase.horizontal and E != EStart and E.Bot.X != E.Next.Top.X)
					@ReverseHorizontal(E)
				E = E.Prev

			if (E.Dx == ClipperLib.ClipperBase.horizontal and E != EStart and E.Bot.X != E.Next.Top.X)
				@ReverseHorizontal(E)

			Result = Result.Prev
			--move to the edge just beyond current bound

		return Result

	AddPath: (pg, polyType, Closed) =>
		if ClipperLib.use_lines
			if not Closed and polyType == ClipperLib.PolyType.ptClip
				ClipperLib.Error("AddPath: Open paths must be subject.")
		else
			if not Closed
				ClipperLib.Error("AddPath: Open paths have been disabled.")

		highI = #pg
		if Closed
			while highI > 1 and ClipperLib.Point.op_Equality(pg[highI], pg[1])
				highI -= 1

		while highI > 1 and ClipperLib.Point.op_Equality(pg[highI], pg[highI - 1])
			highI -= 1

		if (Closed and highI < 3) or (not Closed and highI < 2)
			return false

		edges = {}
		for i = 1, highI
			table.insert(edges, TEdge!)

		IsFlat = true
		
		--1. Basic (first) edge initialization ...
		edges[2].Curr.X = pg[2].X
		edges[2].Curr.Y = pg[2].Y

		
		@InitEdge(edges[1], edges[2], edges[highI], pg[1])
		@InitEdge(edges[highI], edges[1], edges[highI - 1], pg[highI])

		for i = highI - 1, 2, -1
			@InitEdge(edges[i], edges[i + 1], edges[i - 1], pg[i])

		--2. Remove duplicate vertices, and (when closed) collinear edges ...
		eStart = edges[1]
		E = eStart
		eLoopStop = eStart

		while true do
			if (E.Curr == E.Next.Curr and (Closed or E.Next != eStart))
				if E == E.Next
					break

				if E == eStart
					eStart = E.Next

				E = @RemoveEdge(E)
				eLoopStop = E
				continue

			if E.Prev == E.Next
				break
			
			elseif (Closed and ClipperLib.ClipperBase.SlopesEqual(E.Prev.Curr, E.Curr, E.Next.Curr) and (not @PreserveCollinear or @Pt2IsBetweenPt1AndPt3(E.Prev.Curr, E.Curr, E.Next.Curr)))			
				if E == eStart
					eStart = E.Next

				E = @RemoveEdge(E)
				E = E.Prev
				eLoopStop = E
				continue

			E = E.Next
			if (E == eLoopStop) or (not Closed and E.Next == eStart)
				break

		if ((not Closed and (E == E.Next)) or (Closed and (E.Prev == E.Next)))
			return false

		if (not Closed)
			@m_HasOpenPaths = true
			eStart.Prev.OutIdx = ClipperLib.ClipperBase.Skip

		--3. Do second stage of edge initialization ...
		E = eStart

		while true do
			@InitEdge2(E, polyType)
			E = E.Next
			if IsFlat and E.Curr.Y != eStart.Curr.Y
				IsFlat = false

			if E == eStart
				break

		--4. Finally, add edge bounds to LocalMinima list ...
		--Totally flat paths must be handled differently when adding them
		--to LocalMinima list to avoid endless loops etc ...
		if IsFlat
			if Closed
				return false

			E.Prev.OutIdx = ClipperLib.ClipperBase.Skip

			locMin = LocalMinima!
			locMin.Next = nil
			locMin.Y = E.Bot.Y
			locMin.LeftBound = nil
			locMin.RightBound = E
			locMin.RightBound.Side = ClipperLib.EdgeSide.esRight
			locMin.RightBound.WindDelta = 0

			while true do
				if (E.Bot.X != E.Prev.Top.X)
					@ReverseHorizontal(E)
				if (E.Next.OutIdx == ClipperLib.ClipperBase.Skip)
					break
				E.NextInLML = E.Next
				E = E.Next

			@InsertLocalMinima(locMin)
			table.insert(@m_edges, edges)
			return true

		table.insert(@m_edges, edges)
		leftBoundIsForward = nil
		EMin = nil

		--workaround to avoid an endless loop in the while loop below when
		--open paths have matching start and end points ...
		if ClipperLib.Point.op_Equality(E.Prev.Bot, E.Prev.Top)
			E = E.Next

		while true do
			E = @FindNextLocMin(E)
			if E == EMin
				break
			elseif EMin == nil
				EMin = E
			--E and E.Prev now share a local minima (left aligned if horizontal).
			--Compare their slopes to find which starts which bound ...
			locMin = LocalMinima!
			locMin.Next = nil
			locMin.Y = E.Bot.Y
			if E.Dx < E.Prev.Dx
				locMin.LeftBound = E.Prev
				locMin.RightBound = E
				leftBoundIsForward = false

			else
				locMin.LeftBound = E
				locMin.RightBound = E.Prev
				leftBoundIsForward = true

			locMin.LeftBound.Side = ClipperLib.EdgeSide.esLeft
			locMin.RightBound.Side = ClipperLib.EdgeSide.esRight
			if not Closed
				locMin.LeftBound.WindDelta = 0
			elseif locMin.LeftBound.Next == locMin.RightBound
				locMin.LeftBound.WindDelta = -1
			else
				locMin.LeftBound.WindDelta = 1
			locMin.RightBound.WindDelta = -locMin.LeftBound.WindDelta
			E = @ProcessBound(locMin.LeftBound, leftBoundIsForward)
			if (E.OutIdx == ClipperLib.ClipperBase.Skip)
				E = @ProcessBound(E, leftBoundIsForward)
			E2 = @ProcessBound(locMin.RightBound, not leftBoundIsForward)
			if (E2.OutIdx == ClipperLib.ClipperBase.Skip)
				E2 = @ProcessBound(E2, not leftBoundIsForward)
			if (locMin.LeftBound.OutIdx == ClipperLib.ClipperBase.Skip)
				locMin.LeftBound = nil
			elseif (locMin.RightBound.OutIdx == ClipperLib.ClipperBase.Skip)
				locMin.RightBound = nil
			@InsertLocalMinima(locMin)
			if (not leftBoundIsForward)
				E = E2

		return true

	AddPaths: (ppg, polyType, closed) =>
		result = false

		for i = 1, #ppg
			if @AddPath(ppg[i], polyType, closed)
				result = true

		return result

	Pt2IsBetweenPt1AndPt3: (pt1, pt2, pt3) =>
		if ((ClipperLib.Point.op_Equality(pt1, pt3)) or (ClipperLib.Point.op_Equality(pt1, pt2)) or (ClipperLib.Point.op_Equality(pt3, pt2)))
			--if ((pt1 == pt3) || (pt1 == pt2) || (pt3 == pt2))
			return false

		elseif (pt1.X != pt3.X)
			return (pt2.X > pt1.X) == (pt2.X < pt3.X)

		else
			return (pt2.Y > pt1.Y) == (pt2.Y < pt3.Y)

	RemoveEdge: (e) =>
		e.Prev.Next = e.Next
		e.Next.Prev = e.Prev
		result = e.Next
		e.Prev = nil --flag as removed (see ClipperBase.Clear)
		return result

	SetDx: (e) =>
		e.Delta.X = (e.Top.X - e.Bot.X)
		e.Delta.Y = (e.Top.Y - e.Bot.Y)
		if (e.Delta.Y == 0)
			e.Dx = ClipperLib.ClipperBase.horizontal
		else
			e.Dx = (e.Delta.X) / (e.Delta.Y)

	InsertLocalMinima: (newLm) =>
		if (@m_MinimaList == nil)
			@m_MinimaList = newLm

		elseif (newLm.Y >= @m_MinimaList.Y)
			newLm.Next = @m_MinimaList
			@m_MinimaList = newLm

		else
			tmpLm = @m_MinimaList
			while (tmpLm.Next != nil and (newLm.Y < tmpLm.Next.Y))
				tmpLm = tmpLm.Next

			newLm.Next = tmpLm.Next
			tmpLm.Next = newLm

	PopLocalMinima: (Y, current) =>
		current.v = @m_CurrentLM
		if (@m_CurrentLM != nil and @m_CurrentLM.Y == Y)
			@m_CurrentLM = @m_CurrentLM.Next
			return true

		return false

	ReverseHorizontal: (e) =>
		--swap horizontal edges' top and bottom x's so they follow the natural
		--progression of the bounds - ie so their xbots will align with the
		--adjoining lower edge. [Helpful in the ProcessHorizontal() method.]
		tmp = e.Top.X
		e.Top.X = e.Bot.X
		e.Bot.X = tmp

	Reset: =>
		@m_CurrentLM = @m_MinimaList
		if (@m_CurrentLM == nil) -- ie nothing to process
			return

		-- reset all edges ...
		@m_Scanbeam = nil
		lm = @m_MinimaList
		while (lm != nil)
			@InsertScanbeam(lm.Y)

			e = lm.LeftBound
			if (e != nil)
				e.Curr.X = e.Bot.X
				e.Curr.Y = e.Bot.Y
				e.OutIdx = ClipperLib.ClipperBase.Unassigned

			e = lm.RightBound
			if (e != nil)
				e.Curr.X = e.Bot.X
				e.Curr.Y = e.Bot.Y
				e.OutIdx = ClipperLib.ClipperBase.Unassigned

			lm = lm.Next

		@m_ActiveEdges = nil

	InsertScanbeam: (Y) =>
		--single-linked list: sorted descending, ignoring dups.
		if (@m_Scanbeam == nil)
			@m_Scanbeam = Scanbeam!
			@m_Scanbeam.Next = nil
			@m_Scanbeam.Y = Y

		elseif (Y > @m_Scanbeam.Y)
			newSb = Scanbeam!
			newSb.Y = Y
			newSb.Next = @m_Scanbeam
			@m_Scanbeam = newSb

		else
			sb2 = @m_Scanbeam
			while (sb2.Next != nil and Y <= sb2.Next.Y)
				sb2 = sb2.Next

			if (Y == sb2.Y)
				return
			-- ie ignores duplicates

			newSb1 = Scanbeam!
			newSb1.Y = Y
			newSb1.Next = sb2.Next
			sb2.Next = newSb1

	PopScanbeam: (Y) =>
		if (@m_Scanbeam == nil)
			Y.v = 0
			return false

		Y.v = @m_Scanbeam.Y
		@m_Scanbeam = @m_Scanbeam.Next
		return true

	LocalMinimaPending: =>
		return (@m_CurrentLM != nil)

	CreateOutRec: =>
		result = OutRec!
		result.Idx = ClipperLib.ClipperBase.Unassigned
		result.IsHole = false
		result.IsOpen = false
		result.FirstLeft = nil
		result.Pts = nil
		result.BottomPt = nil
		result.PolyNode = nil
		table.insert(@m_PolyOuts, result)
		result.Idx = #@m_PolyOuts
		return result

	DisposeOutRec: (index) =>
		outRec = @m_PolyOuts[index]
		outRec.Pts = nil
		outRec = nil
		@m_PolyOuts[index] = nil

	UpdateEdgeIntoAEL: (e) =>
		if (e.NextInLML == nil)
			ClipperLib.Error("UpdateEdgeIntoAEL: invalid call")

		AelPrev = e.PrevInAEL
		AelNext = e.NextInAEL
		e.NextInLML.OutIdx = e.OutIdx
		if (AelPrev != nil)
			AelPrev.NextInAEL = e.NextInLML

		else
			@m_ActiveEdges = e.NextInLML

		if (AelNext != nil)
			AelNext.PrevInAEL = e.NextInLML

		e.NextInLML.Side = e.Side
		e.NextInLML.WindDelta = e.WindDelta
		e.NextInLML.WindCnt = e.WindCnt
		e.NextInLML.WindCnt2 = e.WindCnt2
		e = e.NextInLML
		e.Curr.X = e.Bot.X
		e.Curr.Y = e.Bot.Y
		e.PrevInAEL = AelPrev
		e.NextInAEL = AelNext
		if (not ClipperLib.ClipperBase.IsHorizontal(e))
			@InsertScanbeam(e.Top.Y)
		return e

	SwapPositionsInAEL: (edge1, edge2) =>
		--check that one or other edge hasn't already been removed from AEL ...
		if (edge1.NextInAEL == edge1.PrevInAEL or edge2.NextInAEL == edge2.PrevInAEL)
			return

		if (edge1.NextInAEL == edge2)
			next = edge2.NextInAEL
			if (next != nil)
				next.PrevInAEL = edge1

			prev = edge1.PrevInAEL
			if (prev != nil)
				prev.NextInAEL = edge2

			edge2.PrevInAEL = prev
			edge2.NextInAEL = edge1
			edge1.PrevInAEL = edge2
			edge1.NextInAEL = next

		elseif (edge2.NextInAEL == edge1)
			next1 = edge1.NextInAEL
			if (next1 != nil)
				next1.PrevInAEL = edge2

			prev1 = edge2.PrevInAEL
			if (prev1 != nil)
				prev1.NextInAEL = edge1

			edge1.PrevInAEL = prev1
			edge1.NextInAEL = edge2
			edge2.PrevInAEL = edge1
			edge2.NextInAEL = next1

		else
			next2 = edge1.NextInAEL
			prev2 = edge1.PrevInAEL
			edge1.NextInAEL = edge2.NextInAEL
			if (edge1.NextInAEL != nil)
				edge1.NextInAEL.PrevInAEL = edge1

			edge1.PrevInAEL = edge2.PrevInAEL
			if (edge1.PrevInAEL != nil)
				edge1.PrevInAEL.NextInAEL = edge1

			edge2.NextInAEL = next2
			if (edge2.NextInAEL != nil)
				edge2.NextInAEL.PrevInAEL = edge2

			edge2.PrevInAEL = prev2
			if (edge2.PrevInAEL != nil)
				edge2.PrevInAEL.NextInAEL = edge2

		if (edge1.PrevInAEL == nil)
			@m_ActiveEdges = edge1

		else
			if (edge2.PrevInAEL == nil)
				@m_ActiveEdges = edge2

	DeleteFromAEL: (e) =>
		AelPrev = e.PrevInAEL
		AelNext = e.NextInAEL
		if (AelPrev == nil and AelNext == nil and e != @m_ActiveEdges)
			return --already deleted

		if (AelPrev != nil)
			AelPrev.NextInAEL = AelNext

		else
			@m_ActiveEdges = AelNext

		if (AelNext != nil)
			AelNext.PrevInAEL = AelPrev

		e.NextInAEL = nil
		e.PrevInAEL = nil

ClipperLib.Clipper.SwapSides = (edge1, edge2) ->
	side = edge1.Side
	edge1.Side = edge2.Side
	edge2.Side = side

ClipperLib.Clipper.SwapPolyIndexes = (edge1, edge2) ->
	outIdx = edge1.OutIdx
	edge1.OutIdx = edge2.OutIdx
	edge2.OutIdx = outIdx

ClipperLib.Clipper.IntersectNodeSort = (node1, node2) ->
	--the following typecast is safe because the differences in Pt.Y will
	--be limited to the height of the scanbeam.
	return (node2.Pt.Y - node1.Pt.Y)

ClipperLib.Clipper.TopX = (edge, currentY) ->
	--if (edge.Bot == edge.Curr) alert ("edge.Bot = edge.Curr");
	--if (edge.Bot == edge.Top) alert ("edge.Bot = edge.Top");
	if (currentY == edge.Top.Y)
		return edge.Top.X
	return edge.Bot.X + edge.Dx * (currentY - edge.Bot.Y)

ClipperLib.Clipper.Orientation = (poly) ->
	return ClipperLib.Clipper.Area(poly) >= 0

ClipperLib.Clipper.GetBounds = (paths) ->
	i = 1
	cnt = #paths
	while (i < cnt and #paths[i] == 0)
		i += 1
	if (i - 1 == cnt)
		return Rect(0, 0, 0, 0)
	result = Rect!
	result.left = paths[i][1].X
	result.right = result.left
	result.top = paths[i][1].Y
	result.bottom = result.top
	for i = 1, cnt
		for j = 1, #paths[i]
			if (paths[i][j].X < result.left)
				result.left = paths[i][j].X
			elseif (paths[i][j].X > result.right)
				result.right = paths[i][j].X
			if (paths[i][j].Y < result.top)
				result.top = paths[i][j].Y
			elseif (paths[i][j].Y > result.bottom)
				result.bottom = paths[i][j].Y

	return result

ClipperLib.Clipper.Area = (poly) ->
	if (not type(poly) != "table")
		return 0
	cnt = #poly
	if (cnt < 3)
		return 0
	a = 0
	for i = 1, cnt - 1
		a += (poly[j].X + poly[i].X) * (poly[j].Y - poly[i].Y)
		j = i

	return -a * 0.5

class Clipper extends ClipperBase
	new: (InitOptions) =>
		if InitOptions == nil then InitOptions = 0
		@m_edges = {} --?

		@m_ClipType = ClipperLib.ClipType.ctIntersection
		@m_ClipFillType = ClipperLib.PolyFillType.pftEvenOdd
		@m_SubjFillType = ClipperLib.PolyFillType.pftEvenOdd
		@m_Scanbeam = nil
		@m_Maxima = nil
		@m_ActiveEdges = nil
		@m_SortedEdges = nil
		@m_IntersectList = {}
		@m_ExecuteLocked = false
		@m_PolyOuts = {}
		@m_Joins = {}
		@m_GhostJoins = {}
		@ReverseSolution = false
		@StrictlySimple = false
		--@PreserveCollinear = false

		@FinalSolution = nil
	
	Clear: =>
		if (#@m_edges == 0)
			return
		@DisposeAllPolyPts!

	InsertMaxima: (X) =>
		--double-linked list: sorted ascending, ignoring dups.
		newMax = Maxima!
		newMax.X = X
		if (@m_Maxima == nil)
			@m_Maxima = newMax
			@m_Maxima.Next = nil
			@m_Maxima.Prev = nil

		elseif (X < @m_Maxima.X)
			newMax.Next = @m_Maxima
			newMax.Prev = nil
			@m_Maxima = newMax

		else
			m = @m_Maxima
			while (m.Next != nil and X >= m.Next.X)
				m = m.Next

			if (X == m.X)
				return
			
			--ie ignores duplicates (& CG to clean up newMax)
			--insert newMax between m and m.Next ...
			newMax.Next = m.Next
			newMax.Prev = m
			if (m.Next != nil)
				m.Next.Prev = newMax

			m.Next = newMax

	Execute: (clipType, subjFillType, clipFillType) =>
		@m_ExecuteLocked = true

		@m_SubjFillType = subjFillType
		@m_ClipFillType = clipFillType
		@m_ClipType = clipType

		succeeded = @ExecuteInternal!
		if (succeeded)
			@BuildResult!

		@DisposeAllPolyPts!
		@m_ExecuteLocked = false

	FixHoleLinkage: (outRec) =>
		--skip if an outermost polygon or
		--already already points to the correct FirstLeft ...
		if (outRec.FirstLeft == nil or (outRec.IsHole != outRec.FirstLeft.IsHole and outRec.FirstLeft.Pts != nil))
			return
		orfl = outRec.FirstLeft

		while (orfl != nil and ((orfl.IsHole == outRec.IsHole) or orfl.Pts == nil))
			orfl = orfl.FirstLeft

		outRec.FirstLeft = orfl

	ExecuteInternal: =>
		@Reset!
		@m_SortedEdges = nil
		@m_Maxima = nil

		botY = {}
		topY = {}

		if (not @PopScanbeam(botY))
			return false

		@InsertLocalMinimaIntoAEL(botY.v)
		while (@PopScanbeam(topY) or @LocalMinimaPending!)
			@ProcessHorizontals!
			@m_GhostJoins = {}
			if (not @ProcessIntersections(topY.v))
				return false
			@ProcessEdgesAtTopOfScanbeam(topY.v)
			botY.v = topY.v
			@InsertLocalMinimaIntoAEL(botY.v)

		--fix orientations ...
		outRec = nil
		--fix orientations ...
		for i = 1, #@m_PolyOuts
			outRec = @m_PolyOuts[i]
			if outRec.Pts == nil or outRec.IsOpen
				continue

			if (BitXOR(outRec.IsHole == true and 1 or 0, @ReverseSolution == true and 1 or 0)) == ((@AreaS1(outRec) > 0) == true and 1 or 0)
				@ReversePolyPtLinks(outRec.Pts)

		@JoinCommonEdges!

		for i = 1, #@m_PolyOuts
			outRec = @m_PolyOuts[i]
			if outRec.Pts == nil
				continue
			elseif outRec.IsOpen
				@FixupOutPolyline(outRec)
			else
				@FixupOutPolygon(outRec)
		if @StrictlySimple
			@DoSimplePolygons!

		@m_Joins = {}
		@m_GhostJoins = {}
		return true

	DisposeAllPolyPts: =>
		for i = 1, #@m_PolyOuts
			@DisposeOutRec(i)
		@m_PolyOuts = ClipperLib.Clear!

	AddJoin: (Op1, Op2, OffPt) =>
		j = Join!
		j.OutPt1 = Op1
		j.OutPt2 = Op2
		j.OffPt.X = OffPt.X
		j.OffPt.Y = OffPt.Y
		table.insert(@m_Joins, j)

	AddGhostJoin: (Op, OffPt) =>
		j = Join!
		j.OutPt1 = Op
		j.OffPt.X = OffPt.X
		j.OffPt.Y = OffPt.Y
		table.insert(@m_GhostJoins, j)

	InsertLocalMinimaIntoAEL: (botY) =>
		lm = {}

		lb = nil
		rb = nil

		while @PopLocalMinima(botY, lm)
			lb = lm.v.LeftBound
			rb = lm.v.RightBound

			Op1 = nil
			if (lb == nil)
				@InsertEdgeIntoAEL(rb, nil)
				@SetWindingCount(rb)
				if @IsContributing(rb)
					Op1 = @AddOutPt(rb, rb.Bot)

			elseif (rb == nil)
				@InsertEdgeIntoAEL(lb, nil)
				@SetWindingCount(lb)

				if @IsContributing(lb)
					Op1 = @AddOutPt(lb, lb.Bot)

				@InsertScanbeam(lb.Top.Y)

			else
				@InsertEdgeIntoAEL(lb, nil)
				@InsertEdgeIntoAEL(rb, lb)
				@SetWindingCount(lb)
				rb.WindCnt = lb.WindCnt
				rb.WindCnt2 = lb.WindCnt2

				if @IsContributing(lb)
					Op1 = @AddLocalMinPoly(lb, rb, lb.Bot)
				
				@InsertScanbeam(lb.Top.Y)

			if (rb != nil)
				if ClipperLib.ClipperBase.IsHorizontal(rb)
					if rb.NextInLML != nil
						@InsertScanbeam(rb.NextInLML.Top.Y)

					@AddEdgeToSEL(rb)

				else
					@InsertScanbeam(rb.Top.Y)

			if (lb == nil or rb == nil)
				continue
			--if output polygons share an Edge with a horizontal rb, they'll need joining later ...
			if (Op1 != nil and ClipperLib.ClipperBase.IsHorizontal(rb) and #@m_GhostJoins > 0 and rb.WindDelta != 0)
				for i = 1, #@m_GhostJoins
					--if the horizontal Rb and a 'ghost' horizontal overlap, then convert
					--the 'ghost' join to a real join ready for later ...
					j = @m_GhostJoins[i]

					if (@HorzSegmentsOverlap(j.OutPt1.Pt.X, j.OffPt.X, rb.Bot.X, rb.Top.X))
						@AddJoin(j.OutPt1, Op1, j.OffPt)

			if (lb.OutIdx >= 0 and lb.PrevInAEL != nil and lb.PrevInAEL.Curr.X == lb.Bot.X and lb.PrevInAEL.OutIdx >= 0 and ClipperLib.ClipperBase.SlopesEqual(lb.PrevInAEL.Curr, lb.PrevInAEL.Top, lb.Curr, lb.Top) and lb.WindDelta != 0 and lb.PrevInAEL.WindDelta != 0)
				Op2 = @AddOutPt(lb.PrevInAEL, lb.Bot)
				@AddJoin(Op1, Op2, lb.Top)

			if (lb.NextInAEL != rb)
				if (rb.OutIdx >= 0 and rb.PrevInAEL.OutIdx >= 0 and ClipperLib.ClipperBase.SlopesEqual(rb.PrevInAEL.Curr, rb.PrevInAEL.Top, rb.Curr, rb.Top) and rb.WindDelta != 0 and rb.PrevInAEL.WindDelta != 0)
					Op2 = @AddOutPt(rb.PrevInAEL, rb.Bot)
					@AddJoin(Op1, Op2, rb.Top)

				e = lb.NextInAEL
				if (e != nil)
					while (e != rb)
						--nb: For calculating winding counts etc, IntersectEdges() assumes
						--that param1 will be to the right of param2 ABOVE the intersection ...
						@IntersectEdges(rb, e, lb.Curr)
						--order important here
						e = e.NextInAEL

	InsertEdgeIntoAEL: (edge, startEdge) =>
		if @m_ActiveEdges == nil
			edge.PrevInAEL = nil
			edge.NextInAEL = nil
			@m_ActiveEdges = edge

		elseif startEdge == nil and @E2InsertsBeforeE1(@m_ActiveEdges, edge)
			edge.PrevInAEL = nil
			edge.NextInAEL = @m_ActiveEdges
			@m_ActiveEdges.PrevInAEL = edge
			@m_ActiveEdges = edge

		else
			if startEdge == nil
				startEdge = @m_ActiveEdges

			while (startEdge.NextInAEL != nil and not @E2InsertsBeforeE1(startEdge.NextInAEL, edge))
				startEdge = startEdge.NextInAEL

			edge.NextInAEL = startEdge.NextInAEL

			if startEdge.NextInAEL != nil
				startEdge.NextInAEL.PrevInAEL = edge

			edge.PrevInAEL = startEdge
			startEdge.NextInAEL = edge

	E2InsertsBeforeE1: (e1, e2) =>
		if (e2.Curr.X == e1.Curr.X)
			if (e2.Top.Y > e1.Top.Y)
				return e2.Top.X < ClipperLib.Clipper.TopX(e1, e2.Top.Y)
			else
				return e1.Top.X > ClipperLib.Clipper.TopX(e2, e1.Top.Y)

		else
			return e2.Curr.X < e1.Curr.X

	IsEvenOddFillType: (edge) =>
		if (edge.PolyTyp == ClipperLib.PolyType.ptSubject)
			return @m_SubjFillType == ClipperLib.PolyFillType.pftEvenOdd

		else
			return @m_ClipFillType == ClipperLib.PolyFillType.pftEvenOdd

	IsEvenOddAltFillType: (edge) =>
		if (edge.PolyTyp == ClipperLib.PolyType.ptSubject)
			return @m_ClipFillType == ClipperLib.PolyFillType.pftEvenOdd

		else
			return @m_SubjFillType == ClipperLib.PolyFillType.pftEvenOdd

	IsContributing: (edge) =>
		pft = nil
		pft2 = nil

		if (edge.PolyTyp == ClipperLib.PolyType.ptSubject)
			pft = @m_SubjFillType
			pft2 = @m_ClipFillType

		else
			pft = @m_ClipFillType
			pft2 = @m_SubjFillType

		switch pft
			when ClipperLib.PolyFillType.pftEvenOdd
				if (edge.WindDelta == 0 and edge.WindCnt != 1)
					return false

			when ClipperLib.PolyFillType.pftNonZero
				if (math.abs(edge.WindCnt) != 1)
					return false

			when ClipperLib.PolyFillType.pftPositive
				if (edge.WindCnt != 1)
					return false

			else
				if (edge.WindCnt != -1)
					return false

		switch @m_ClipType
			when ClipperLib.ClipType.ctIntersection
				switch (pft2)
					when ClipperLib.PolyFillType.pftEvenOdd
						return (edge.WindCnt2 != 0)

					when ClipperLib.PolyFillType.pftNonZero
						return (edge.WindCnt2 != 0)

					when ClipperLib.PolyFillType.pftPositive
						return (edge.WindCnt2 > 0)

					else
						return (edge.WindCnt2 < 0)

			when ClipperLib.ClipType.ctUnion
				switch (pft2)
					when ClipperLib.PolyFillType.pftEvenOdd
						return (edge.WindCnt2 == 0)

					when ClipperLib.PolyFillType.pftNonZero
						return (edge.WindCnt2 == 0)

					when ClipperLib.PolyFillType.pftPositive
						return (edge.WindCnt2 <= 0)

					else
						return (edge.WindCnt2 >= 0)

			when ClipperLib.ClipType.ctDifference
				if (edge.PolyTyp == ClipperLib.PolyType.ptSubject)
					switch (pft2)
						when ClipperLib.PolyFillType.pftEvenOdd
							return (edge.WindCnt2 == 0)

						when ClipperLib.PolyFillType.pftNonZero
							return (edge.WindCnt2 == 0)

						when ClipperLib.PolyFillType.pftPositive
							return (edge.WindCnt2 <= 0)

						else
							return (edge.WindCnt2 >= 0)

				else
					switch (pft2)
						when ClipperLib.PolyFillType.pftEvenOdd
							return (edge.WindCnt2 != 0)

						when ClipperLib.PolyFillType.pftNonZero
							return (edge.WindCnt2 != 0)

						when ClipperLib.PolyFillType.pftPositive
							return (edge.WindCnt2 > 0)

						else
							return (edge.WindCnt2 < 0)

			when ClipperLib.ClipType.ctXor
				if (edge.WindDelta == 0)
					switch (pft2)
						when ClipperLib.PolyFillType.pftEvenOdd
							return (edge.WindCnt2 == 0)

						when ClipperLib.PolyFillType.pftNonZero
							return (edge.WindCnt2 == 0)

						when ClipperLib.PolyFillType.pftPositive
							return (edge.WindCnt2 <= 0)

						else
							return (edge.WindCnt2 >= 0)

				else
					return true

		return true

	SetWindingCount: (edge) =>
		e = edge.PrevInAEL
		--find the edge of the same polytype that immediately preceeds 'edge' in AEL
		while (e != nil and ((e.PolyTyp != edge.PolyTyp) or (e.WindDelta == 0)))
			e = e.PrevInAEL

		if (e == nil)

			pft = nil
			if edge.PolyTyp == ClipperLib.PolyType.ptSubject
				pft = @m_SubjFillType
			else
				pft = @m_ClipFillType
			
			if (edge.WindDelta == 0)
				edge.WindCnt = nil
				if pft == ClipperLib.PolyFillType.pftNegative
					edge.WindCnt = -1
				else
					edge.WindCnt = 1
			else
				edge.WindCnt = edge.WindDelta

			edge.WindCnt2 = 0
			e = @m_ActiveEdges
			--ie get ready to calc WindCnt2

		elseif (edge.WindDelta == 0 and @m_ClipType != ClipperLib.ClipType.ctUnion)
			edge.WindCnt = 1
			edge.WindCnt2 = e.WindCnt2
			e = e.NextInAEL
			--ie get ready to calc WindCnt2

		elseif (@IsEvenOddFillType(edge))
			--EvenOdd filling ...
			if (edge.WindDelta == 0)
				--are we inside a subj polygon ...
				Inside = true
				e2 = e.PrevInAEL
				while (e2 != nil)
					if (e2.PolyTyp == e.PolyTyp and e2.WindDelta != 0)
						Inside = not Inside
					e2 = e2.PrevInAEL

				edge.WindCnt = nil
				if Inside
					edge.WindCnt = 0
				else
					edge.WindCnt = 1

			else
				edge.WindCnt = edge.WindDelta

			edge.WindCnt2 = e.WindCnt2
			e = e.NextInAEL
			--ie get ready to calc WindCnt2

		else
			--nonZero, Positive or Negative filling ...
			if (e.WindCnt * e.WindDelta < 0)
				--prev edge is 'decreasing' WindCount (WC) toward zero
				--so we're outside the previous polygon ...
				if (math.abs(e.WindCnt) > 1)
					--outside prev poly but still inside another.
					--when reversing direction of prev poly use the same WC
					if (e.WindDelta * edge.WindDelta < 0)
						edge.WindCnt = e.WindCnt
					else
						edge.WindCnt = e.WindCnt + edge.WindDelta

				else
					edge.WindCnt = nil
					if edge.WindDelta == 0
						edge.WindCnt = 1
					else
						edge.WindCnt = edge.WindDelta

			else
				--prev edge is 'increasing' WindCount (WC) away from zero
				--so we're inside the previous polygon ...
				if (edge.WindDelta == 0)
					edge.WindCnt = nil
					if e.WindCnt < 0
						edge.WindCnt = e.WindCnt - 1
					else
						edge.WindCnt = e.WindCnt + 1

				else if (e.WindDelta * edge.WindDelta < 0)
					edge.WindCnt = e.WindCnt
				else
					edge.WindCnt = e.WindCnt + edge.WindDelta

			edge.WindCnt2 = e.WindCnt2
			e = e.NextInAEL
			--ie get ready to calc WindCnt2

		--update WindCnt2 ...
		if (@IsEvenOddAltFillType(edge))
			--EvenOdd filling ...
			while (e != edge)
				if (e.WindDelta != 0)

					edge.TempWindCnt2 = nil
					if edge.WindCnt2 == 0
						edge.TempWindCnt2 = 1
					else
						edge.TempWindCnt2 = 0
					edge.WindCnt2 = edge.TempWindCnt2

				e = e.NextInAEL

		else
			--nonZero, Positive or Negative filling ...
			while (e != edge)
				edge.WindCnt2 += e.WindDelta
				e = e.NextInAEL

	AddEdgeToSEL: (edge) =>
		--SEL pointers in PEdge are use to build transient lists of horizontal edges.
		--However, since we don't need to worry about processing order, all additions
		--are made to the front of the list ...
		if (@m_SortedEdges == nil)
			@m_SortedEdges = edge
			edge.PrevInSEL = nil
			edge.NextInSEL = nil
		else
			edge.NextInSEL = @m_SortedEdges
			edge.PrevInSEL = nil
			@m_SortedEdges.PrevInSEL = edge
			@m_SortedEdges = edge

	PopEdgeFromSEL: (e) =>
		--Pop edge from front of SEL (ie SEL is a FILO list)
		e.v = @m_SortedEdges
		if (e.v == nil)
			return false

		oldE = e.v
		@m_SortedEdges = e.v.NextInSEL
		if (@m_SortedEdges != nil)
			@m_SortedEdges.PrevInSEL = nil

		oldE.NextInSEL = nil
		oldE.PrevInSEL = nil
		return true

	CopyAELToSEL: =>
		e = @m_ActiveEdges
		@m_SortedEdges = e
		while (e != nil)
			e.PrevInSEL = e.PrevInAEL
			e.NextInSEL = e.NextInAEL
			e = e.NextInAEL

	SwapPositionsInSEL: (edge1, edge2) =>
		if (edge1.NextInSEL == nil and edge1.PrevInSEL == nil)
			return
		if (edge2.NextInSEL == nil and edge2.PrevInSEL == nil)
			return
		if (edge1.NextInSEL == edge2)
			next = edge2.NextInSEL
			if (next != nil)
				next.PrevInSEL = edge1
			prev = edge1.PrevInSEL

			if (prev != nil)
				prev.NextInSEL = edge2

			edge2.PrevInSEL = prev
			edge2.NextInSEL = edge1
			edge1.PrevInSEL = edge2
			edge1.NextInSEL = next

		elseif (edge2.NextInSEL == edge1)
			next = edge1.NextInSEL

			if (next != nil)
				next.PrevInSEL = edge2

			prev = edge2.PrevInSEL
			if (prev != nil)
				prev.NextInSEL = edge1

			edge1.PrevInSEL = prev
			edge1.NextInSEL = edge2
			edge2.PrevInSEL = edge1
			edge2.NextInSEL = next

		else
			next = edge1.NextInSEL
			prev = edge1.PrevInSEL
			edge1.NextInSEL = edge2.NextInSEL

			if (edge1.NextInSEL != nil)
				edge1.NextInSEL.PrevInSEL = edge1
			edge1.PrevInSEL = edge2.PrevInSEL

			if (edge1.PrevInSEL != nil)
				edge1.PrevInSEL.NextInSEL = edge1
			edge2.NextInSEL = next

			if (edge2.NextInSEL != nil)
				edge2.NextInSEL.PrevInSEL = edge2
			edge2.PrevInSEL = prev

			if (edge2.PrevInSEL != nil)
				edge2.PrevInSEL.NextInSEL = edge2

		if (edge1.PrevInSEL == nil)
			@m_SortedEdges = edge1

		elseif (edge2.PrevInSEL == nil)
			@m_SortedEdges = edge2

	AddLocalMaxPoly: (e1, e2, pt) =>
		@AddOutPt(e1, pt)

		if (e2.WindDelta == 0)
			@AddOutPt(e2, pt)

		if (e1.OutIdx == e2.OutIdx)
			e1.OutIdx = -1
			e2.OutIdx = -1

		elseif (e1.OutIdx < e2.OutIdx)
			@AppendPolygon(e1, e2)

		else
			@AppendPolygon(e2, e1)

	AddLocalMinPoly: (e1, e2, pt) =>
		result = nil
		e = nil
		prevE = nil

		if (ClipperLib.ClipperBase.IsHorizontal(e2) or (e1.Dx > e2.Dx))
			result = @AddOutPt(e1, pt)
			e2.OutIdx = e1.OutIdx
			e1.Side = ClipperLib.EdgeSide.esLeft
			e2.Side = ClipperLib.EdgeSide.esRight
			e = e1
			if (e.PrevInAEL == e2)
				prevE = e2.PrevInAEL
			else
				prevE = e.PrevInAEL

		else
			result = @AddOutPt(e2, pt)
			e1.OutIdx = e2.OutIdx
			e1.Side = ClipperLib.EdgeSide.esRight
			e2.Side = ClipperLib.EdgeSide.esLeft
			e = e2
			if (e.PrevInAEL == e1)
				prevE = e1.PrevInAEL
			else
				prevE = e.PrevInAEL

		if (prevE != nil and prevE.OutIdx >= 0 and prevE.Top.Y < pt.Y and e.Top.Y < pt.Y)
			xPrev = ClipperLib.Clipper.TopX(prevE, pt.Y)
			xE = ClipperLib.Clipper.TopX(e, pt.Y)

			if ((xPrev == xE) and (e.WindDelta != 0) and (prevE.WindDelta != 0) and ClipperLib.ClipperBase.SlopesEqual(Point(xPrev, pt.Y), prevE.Top, Point(xE, pt.Y), e.Top))
				outPt = @AddOutPt(prevE, pt)
				@AddJoin(result, outPt, e.Top)

		return result

	AddOutPt: (e, pt) =>
		if (e.OutIdx < 0)
			outRec = @CreateOutRec!
			outRec.IsOpen = (e.WindDelta == 0)
			newOp = OutPt!
			outRec.Pts = newOp
			newOp.Idx = outRec.Idx

			newOp.Pt.X = pt.X
			newOp.Pt.Y = pt.Y

			newOp.Next = newOp
			newOp.Prev = newOp
			if (not outRec.IsOpen)
				@SetHoleState(e, outRec)
			e.OutIdx = outRec.Idx
			return newOp

		else
			outRec = @m_PolyOuts[e.OutIdx]
			--OutRec.Pts is the 'Left-most' point & OutRec.Pts.Prev is the 'Right-most'
			op = outRec.Pts
			ToFront = (e.Side == ClipperLib.EdgeSide.esLeft)
			if (ToFront and ClipperLib.Point.op_Equality(pt, op.Pt))
				return op

			elseif (not ToFront and ClipperLib.Point.op_Equality(pt, op.Prev.Pt))
				return op.Prev
			newOp = OutPt!
			newOp.Idx = outRec.Idx

			newOp.Pt.X = pt.X
			newOp.Pt.Y = pt.Y

			newOp.Next = op
			newOp.Prev = op.Prev
			newOp.Prev.Next = newOp
			op.Prev = newOp
			if (ToFront)
				outRec.Pts = newOp

			return newOp

	GetLastOutPt: (e) =>
		outRec = @m_PolyOuts[e.OutIdx]

		if (e.Side == ClipperLib.EdgeSide.esLeft)
			return outRec.Pts

		else
			return outRec.Pts.Prev

	SwapPoints: (pt1, pt2) =>
		tmp = Point(pt1.Value)

		pt1.Value.X = pt2.Value.X
		pt1.Value.Y = pt2.Value.Y

		pt2.Value.X = tmp.X
		pt2.Value.Y = tmp.Y

	HorzSegmentsOverlap: (seg1a, seg1b, seg2a, seg2b) =>
		tmp = nil
		if (seg1a > seg1b)
			tmp = seg1a
			seg1a = seg1b
			seg1b = tmp

		if (seg2a > seg2b)
			tmp = seg2a
			seg2a = seg2b
			seg2b = tmp

		return (seg1a < seg2b) and (seg2a < seg1b)

	SetHoleState: (e, outRec) =>
		e2 = e.PrevInAEL
		eTmp = nil

		while (e2 != nil)
			if (e2.OutIdx >= 0 and e2.WindDelta != 0)
				if (eTmp == nil)
					eTmp = e2
				elseif (eTmp.OutIdx == e2.OutIdx)
					eTmp = nil --paired

			e2 = e2.PrevInAEL

		if (eTmp == nil)
			outRec.FirstLeft = nil
			outRec.IsHole = false

		else
			outRec.FirstLeft = @m_PolyOuts[eTmp.OutIdx]
			outRec.IsHole = not outRec.FirstLeft.IsHole

	GetDx: (pt1, pt2) =>
		if (pt1.Y == pt2.Y)
			return ClipperLib.ClipperBase.horizontal
		else
			return (pt2.X - pt1.X) / (pt2.Y - pt1.Y)

	FirstIsBottomPt: (btmPt1, btmPt2) =>
		p = btmPt1.Prev
		while ((ClipperLib.Point.op_Equality(p.Pt, btmPt1.Pt)) and (p != btmPt1))
			p = p.Prev
		dx1p = math.abs(@GetDx(btmPt1.Pt, p.Pt))

		p = btmPt1.Next
		while ((ClipperLib.Point.op_Equality(p.Pt, btmPt1.Pt)) and (p != btmPt1))
			p = p.Next
		dx1n = math.abs(@GetDx(btmPt1.Pt, p.Pt))

		p = btmPt2.Prev
		while ((ClipperLib.Point.op_Equality(p.Pt, btmPt2.Pt)) and (p != btmPt2))
			p = p.Prev
		dx2p = math.abs(@GetDx(btmPt2.Pt, p.Pt))

		p = btmPt2.Next
		while ((ClipperLib.Point.op_Equality(p.Pt, btmPt2.Pt)) and (p != btmPt2))
			p = p.Next
		dx2n = math.abs(@GetDx(btmPt2.Pt, p.Pt))

		if (math.max(dx1p, dx1n) == math.max(dx2p, dx2n) and math.min(dx1p, dx1n) == math.min(dx2p, dx2n))
			return @Area(btmPt1) > 0 -- if otherwise identical use orientation
		else
			return (dx1p >= dx2p and dx1p >= dx2n) or (dx1n >= dx2p and dx1n >= dx2n)

	GetBottomPt: (pp) =>
		dups = nil
		p = pp.Next

		while (p != pp)
			if (p.Pt.Y > pp.Pt.Y)
				pp = p
				dups = nil

			else if (p.Pt.Y == pp.Pt.Y and p.Pt.X <= pp.Pt.X)
				if (p.Pt.X < pp.Pt.X)
					dups = nil
					pp = p

				else
					if (p.Next != pp and p.Prev != pp)
						dups = p

			p = p.Next

		if (dups != nil)
			--there appears to be at least 2 vertices at bottomPt so ...
			while (dups != p)
				if (not @FirstIsBottomPt(p, dups))
					pp = dups

				dups = dups.Next
				while (ClipperLib.Point.op_Inequality(dups.Pt, pp.Pt))
					dups = dups.Next

		return pp

	GetLowermostRec: (outRec1, outRec2) =>
		--work out which polygon fragment has the correct hole state ...
		if (outRec1.BottomPt == nil)
			outRec1.BottomPt = @GetBottomPt(outRec1.Pts)

		if (outRec2.BottomPt == nil)
			outRec2.BottomPt = @GetBottomPt(outRec2.Pts)

		bPt1 = outRec1.BottomPt
		bPt2 = outRec2.BottomPt
		if (bPt1.Pt.Y > bPt2.Pt.Y)
			return outRec1

		elseif (bPt1.Pt.Y < bPt2.Pt.Y)
			return outRec2

		elseif (bPt1.Pt.X < bPt2.Pt.X)
			return outRec1

		elseif (bPt1.Pt.X > bPt2.Pt.X)
			return outRec2

		elseif (bPt1.Next == bPt1)
			return outRec2

		elseif (bPt2.Next == bPt2)
			return outRec1

		elseif (@FirstIsBottomPt(bPt1, bPt2))
			return outRec1

		else
			return outRec2

	OutRec1RightOfOutRec2: (outRec1, outRec2) =>
		while true do
			outRec1 = outRec1.FirstLeft
			if (outRec1 == outRec2)
				return true

			if (outRec1 == nil)
				break
		
		return false

	GetOutRec: (idx) =>
		outrec = @m_PolyOuts[idx]
		while (outrec != @m_PolyOuts[outrec.Idx])
			outrec = @m_PolyOuts[outrec.Idx]

		return outrec

	AppendPolygon: (e1, e2) =>
		--get the start and ends of both output polygons ...
		outRec1 = @m_PolyOuts[e1.OutIdx]
		outRec2 = @m_PolyOuts[e2.OutIdx]
		holeStateRec = nil

		if (@OutRec1RightOfOutRec2(outRec1, outRec2))
			holeStateRec = outRec2
		elseif (@OutRec1RightOfOutRec2(outRec2, outRec1))
			holeStateRec = outRec1
		else
			holeStateRec = @GetLowermostRec(outRec1, outRec2)

		--get the start and ends of both output polygons and
		--join E2 poly onto E1 poly and delete pointers to E2 ...

		p1_lft = outRec1.Pts
		p1_rt = p1_lft.Prev
		p2_lft = outRec2.Pts
		p2_rt = p2_lft.Prev
		--join e2 poly onto e1 poly and delete pointers to e2 ...
		if (e1.Side == ClipperLib.EdgeSide.esLeft)
			if (e2.Side == ClipperLib.EdgeSide.esLeft)
				--z y x a b c
				@ReversePolyPtLinks(p2_lft)
				p2_lft.Next = p1_lft
				p1_lft.Prev = p2_lft
				p1_rt.Next = p2_rt
				p2_rt.Prev = p1_rt
				outRec1.Pts = p2_rt
			else
				--x y z a b c
				p2_rt.Next = p1_lft
				p1_lft.Prev = p2_rt
				p2_lft.Prev = p1_rt
				p1_rt.Next = p2_lft
				outRec1.Pts = p2_lft

		else
			if (e2.Side == ClipperLib.EdgeSide.esRight)
				--a b c z y x
				@ReversePolyPtLinks(p2_lft)
				p1_rt.Next = p2_rt
				p2_rt.Prev = p1_rt
				p2_lft.Next = p1_lft
				p1_lft.Prev = p2_lft
			else
				--a b c x y z
				p1_rt.Next = p2_lft
				p2_lft.Prev = p1_rt
				p1_lft.Prev = p2_rt
				p2_rt.Next = p1_lft

		outRec1.BottomPt = nil
		if (holeStateRec == outRec2)
			if (outRec2.FirstLeft != outRec1)
				outRec1.FirstLeft = outRec2.FirstLeft
			outRec1.IsHole = outRec2.IsHole

		outRec2.Pts = nil
		outRec2.BottomPt = nil
		outRec2.FirstLeft = outRec1
		OKIdx = e1.OutIdx
		ObsoleteIdx = e2.OutIdx
		e1.OutIdx = -1
		--nb: safe because we only get here via AddLocalMaxPoly
		e2.OutIdx = -1
		e = @m_ActiveEdges
		while (e != nil)
			if (e.OutIdx == ObsoleteIdx)
				e.OutIdx = OKIdx
				e.Side = e1.Side
				break

			e = e.NextInAEL

		outRec2.Idx = outRec1.Idx

	ReversePolyPtLinks: (pp) =>
		if (pp == nil)
			return

		pp1 = nil
		pp2 = nil
		pp1 = pp

		while true do
			pp2 = pp1.Next
			pp1.Next = pp1.Prev
			pp1.Prev = pp2
			pp1 = pp2

			if pp1 == pp
				break
		

	IntersectEdges: (e1, e2, pt) =>
		--e1 will be to the left of e2 BELOW the intersection. Therefore e1 is before
		--e2 in AEL except when e1 is being inserted at the intersection point ...
		e1Contributing = (e1.OutIdx >= 0)
		e2Contributing = (e2.OutIdx >= 0)

		if (ClipperLib.use_lines)
			--if either edge is on an OPEN path ...
			if (e1.WindDelta == 0 or e2.WindDelta == 0)
				--ignore subject-subject open path intersections UNLESS they
				--are both open paths, AND they are both 'contributing maximas' ...
				if (e1.WindDelta == 0 and e2.WindDelta == 0)
					return
				--if intersecting a subj line with a subj poly ...
				elseif (e1.PolyTyp == e2.PolyTyp and e1.WindDelta != e2.WindDelta and @m_ClipType == ClipperLib.ClipType.ctUnion)
					if (e1.WindDelta == 0)
						if (e2Contributing)
							@AddOutPt(e1, pt)
							if (e1Contributing)
								e1.OutIdx = -1

					else
						if (e1Contributing)
							@AddOutPt(e2, pt)
							if (e2Contributing)
								e2.OutIdx = -1

				elseif (e1.PolyTyp != e2.PolyTyp)
					if ((e1.WindDelta == 0) and math.abs(e2.WindCnt) == 1 and (@m_ClipType != ClipperLib.ClipType.ctUnion or e2.WindCnt2 == 0))
						@AddOutPt(e1, pt)
						if (e1Contributing)
							e1.OutIdx = -1

					else if ((e2.WindDelta == 0) and (math.abs(e1.WindCnt) == 1) and (@m_ClipType != ClipperLib.ClipType.ctUnion or e1.WindCnt2 == 0))
						@AddOutPt(e2, pt)
						if (e2Contributing)
							e2.OutIdx = -1

				return

		--update winding counts...
		--assumes that e1 will be to the Right of e2 ABOVE the intersection
		if (e1.PolyTyp == e2.PolyTyp)
			if (@IsEvenOddFillType(e1))
				oldE1WindCnt = e1.WindCnt
				e1.WindCnt = e2.WindCnt
				e2.WindCnt = oldE1WindCnt
			else
				if (e1.WindCnt + e2.WindDelta == 0)
					e1.WindCnt = -e1.WindCnt
				else
					e1.WindCnt += e2.WindDelta
				if (e2.WindCnt - e1.WindDelta == 0)
					e2.WindCnt = -e2.WindCnt
				else
					e2.WindCnt -= e1.WindDelta

		else
			if (not @IsEvenOddFillType(e2))
				e1.WindCnt2 += e2.WindDelta
			else
				e1.WindCnt2 = e1.WindCnt2 == 0 and 1 or 0
			if (not @IsEvenOddFillType(e1))
				e2.WindCnt2 -= e1.WindDelta
			else
				e2.WindCnt2 = e2.WindCnt2 == 0 and 1 or 0

		e1FillType, e2FillType, e1FillType2, e2FillType2 = nil
		if (e1.PolyTyp == ClipperLib.PolyType.ptSubject)
			e1FillType = @m_SubjFillType
			e1FillType2 = @m_ClipFillType
		else
			e1FillType = @m_ClipFillType
			e1FillType2 = @m_SubjFillType

		if (e2.PolyTyp == ClipperLib.PolyType.ptSubject)
			e2FillType = @m_SubjFillType
			e2FillType2 = @m_ClipFillType
		else
			e2FillType = @m_ClipFillType
			e2FillType2 = @m_SubjFillType

		e1Wc, e2Wc = nil

		switch (e1FillType)
			when ClipperLib.PolyFillType.pftPositive
				e1Wc = e1.WindCnt
			when ClipperLib.PolyFillType.pftNegative
				e1Wc = -e1.WindCnt
			else
				e1Wc = math.abs(e1.WindCnt)

		switch (e2FillType)
			when ClipperLib.PolyFillType.pftPositive
				e2Wc = e2.WindCnt
			when ClipperLib.PolyFillType.pftNegative
				e2Wc = -e2.WindCnt
			else
				e2Wc = math.abs(e2.WindCnt)

		if (e1Contributing and e2Contributing)
			if ((e1Wc != 0 and e1Wc != 1) or (e2Wc != 0 and e2Wc != 1) or (e1.PolyTyp != e2.PolyTyp and @m_ClipType != ClipperLib.ClipType.ctXor))
				@AddLocalMaxPoly(e1, e2, pt)
			else
				@AddOutPt(e1, pt)
				@AddOutPt(e2, pt)
				ClipperLib.Clipper.SwapSides(e1, e2)
				ClipperLib.Clipper.SwapPolyIndexes(e1, e2)

		elseif (e1Contributing)
			if (e2Wc == 0 or e2Wc == 1)
				@AddOutPt(e1, pt)
				ClipperLib.Clipper.SwapSides(e1, e2)
				ClipperLib.Clipper.SwapPolyIndexes(e1, e2)

		elseif (e2Contributing)
			if (e1Wc == 0 or e1Wc == 1)
				@AddOutPt(e2, pt)
				ClipperLib.Clipper.SwapSides(e1, e2)
				ClipperLib.Clipper.SwapPolyIndexes(e1, e2)

		elseif ((e1Wc == 0 or e1Wc == 1) and (e2Wc == 0 or e2Wc == 1))
			--neither edge is currently contributing ...
			e1Wc2, e2Wc2 = nil
			switch (e1FillType2)
				when ClipperLib.PolyFillType.pftPositive
					e1Wc2 = e1.WindCnt2
				when ClipperLib.PolyFillType.pftNegative
					e1Wc2 = -e1.WindCnt2
				else
					e1Wc2 = math.abs(e1.WindCnt2)

			switch (e2FillType2)
				when ClipperLib.PolyFillType.pftPositive
					e2Wc2 = e2.WindCnt2
				when ClipperLib.PolyFillType.pftNegative
					e2Wc2 = -e2.WindCnt2
				else
					e2Wc2 = math.abs(e2.WindCnt2)


			if (e1.PolyTyp != e2.PolyTyp)
				@AddLocalMinPoly(e1, e2, pt)

			elseif (e1Wc == 1 and e2Wc == 1)
				switch (@m_ClipType)
					when ClipperLib.ClipType.ctIntersection
						if (e1Wc2 > 0 and e2Wc2 > 0)
							@AddLocalMinPoly(e1, e2, pt)
					when ClipperLib.ClipType.ctUnion
						if (e1Wc2 <= 0 and e2Wc2 <= 0)
							@AddLocalMinPoly(e1, e2, pt)
					when ClipperLib.ClipType.ctDifference
						if (((e1.PolyTyp == ClipperLib.PolyType.ptClip) and (e1Wc2 > 0) and (e2Wc2 > 0)) or ((e1.PolyTyp == ClipperLib.PolyType.ptSubject) and (e1Wc2 <= 0) and (e2Wc2 <= 0)))
							@AddLocalMinPoly(e1, e2, pt)
					when ClipperLib.ClipType.ctXor
						@AddLocalMinPoly(e1, e2, pt)

			else
				ClipperLib.Clipper.SwapSides(e1, e2)

	DeleteFromSEL: (e) =>
		SelPrev = e.PrevInSEL
		SelNext = e.NextInSEL
		if (SelPrev == nil and SelNext == nil and (e != @m_SortedEdges))
			return
		--already deleted
		if (SelPrev != nil)
			SelPrev.NextInSEL = SelNext
		else
			@m_SortedEdges = SelNext
		if (SelNext != nil)
			SelNext.PrevInSEL = SelPrev
		e.NextInSEL = nil
		e.PrevInSEL = nil

	ProcessHorizontals: =>
		horzEdge = {}

		while @PopEdgeFromSEL(horzEdge)
			@ProcessHorizontal(horzEdge.v)

	GetHorzDirection: (HorzEdge, Svar) =>
		if (HorzEdge.Bot.X < HorzEdge.Top.X)
			Svar.Left = HorzEdge.Bot.X
			Svar.Right = HorzEdge.Top.X
			Svar.Dir = ClipperLib.Direction.dLeftToRight
		else
			Svar.Left = HorzEdge.Top.X
			Svar.Right = HorzEdge.Bot.X
			Svar.Dir = ClipperLib.Direction.dRightToLeft

	ProcessHorizontal: (horzEdge) =>
		Svar = {
			Dir: nil,
			Left: nil,
			Right: nil
		}

		@GetHorzDirection(horzEdge, Svar)
		dir = Svar.Dir
		horzLeft = Svar.Left
		horzRight = Svar.Right

		IsOpen = horzEdge.WindDelta == 0

		eLastHorz = horzEdge
		eMaxPair = nil

		while (eLastHorz.NextInLML != nil and ClipperLib.ClipperBase.IsHorizontal(eLastHorz.NextInLML))
			eLastHorz = eLastHorz.NextInLML
		if (eLastHorz.NextInLML == nil)
			eMaxPair = @GetMaximaPair(eLastHorz)

		currMax = @m_Maxima
		if (currMax != nil)
			--get the first maxima in range (X) ...
			if (dir == ClipperLib.Direction.dLeftToRight)
				while (currMax != nil and currMax.X <= horzEdge.Bot.X)
					currMax = currMax.Next

				if (currMax != nil and currMax.X >= eLastHorz.Top.X)
					currMax = nil

			else
				while (currMax.Next != nil and currMax.Next.X < horzEdge.Bot.X)
					currMax = currMax.Next
				if (currMax.X <= eLastHorz.Top.X)
					currMax = nil

		op1 = nil
		while true do --loop through consec. horizontal edges
			IsLastHorz = (horzEdge == eLastHorz)
			e = @GetNextInAEL(horzEdge, dir)
			while (e != nil)
				--this code block inserts extra coords into horizontal edges (in output
				--polygons) whereever maxima touch these horizontal edges. This helps
				--'simplifying' polygons (ie if the Simplify property is set).
				if (currMax != nil)
					if (dir == ClipperLib.Direction.dLeftToRight)
						while (currMax != nil and currMax.X < e.Curr.X)
							if (horzEdge.OutIdx >= 0 and not IsOpen)
								@AddOutPt(horzEdge, Point(currMax.X, horzEdge.Bot.Y))
							currMax = currMax.Next

					else
						while (currMax != nil and currMax.X > e.Curr.X)
							if (horzEdge.OutIdx >= 0 and not IsOpen)
								@AddOutPt(horzEdge, Point(currMax.X, horzEdge.Bot.Y))
							currMax = currMax.Prev

				if ((dir == ClipperLib.Direction.dLeftToRight and e.Curr.X > horzRight) or (dir == ClipperLib.Direction.dRightToLeft and e.Curr.X < horzLeft))
					break

				--Also break if we've got to the end of an intermediate horizontal edge ...
				--nb: Smaller Dx's are to the right of larger Dx's ABOVE the horizontal.
				if (e.Curr.X == horzEdge.Top.X and horzEdge.NextInLML != nil and e.Dx < horzEdge.NextInLML.Dx)
					break

				if (horzEdge.OutIdx >= 0 and not IsOpen) --note: may be done multiple times
					op1 = @AddOutPt(horzEdge, e.Curr)
					eNextHorz = @m_SortedEdges
					while (eNextHorz != nil)
						if (eNextHorz.OutIdx >= 0 and @HorzSegmentsOverlap(horzEdge.Bot.X, horzEdge.Top.X, eNextHorz.Bot.X, eNextHorz.Top.X))
							op2 = @GetLastOutPt(eNextHorz)
							@AddJoin(op2, op1, eNextHorz.Top)

						eNextHorz = eNextHorz.NextInSEL

					@AddGhostJoin(op1, horzEdge.Bot)

				--OK, so far we're still in range of the horizontal Edge  but make sure
				--we're at the last of consec. horizontals when matching with eMaxPair
				if (e == eMaxPair and IsLastHorz)
					if (horzEdge.OutIdx >= 0)
						@AddLocalMaxPoly(horzEdge, eMaxPair, horzEdge.Top)

					@DeleteFromAEL(horzEdge)
					@DeleteFromAEL(eMaxPair)
					return

				if (dir == ClipperLib.Direction.dLeftToRight)

					Pt = Point(e.Curr.X, horzEdge.Curr.Y)
					@IntersectEdges(horzEdge, e, Pt)

				else
					Pt = Point(e.Curr.X, horzEdge.Curr.Y)
					@IntersectEdges(e, horzEdge, Pt)

				eNext = @GetNextInAEL(e, dir)
				@SwapPositionsInAEL(horzEdge, e)
				e = eNext

			--Break out of loop if HorzEdge.NextInLML is not also horizontal ...
			if (horzEdge.NextInLML == nil or not ClipperLib.ClipperBase.IsHorizontal(horzEdge.NextInLML))
				break

			horzEdge = @UpdateEdgeIntoAEL(horzEdge)
			if (horzEdge.OutIdx >= 0)
				@AddOutPt(horzEdge, horzEdge.Bot)

			Svar = {
				Dir: dir,
				Left: horzLeft,
				Right: horzRight
			}

			@GetHorzDirection(horzEdge, Svar)
			dir = Svar.Dir
			horzLeft = Svar.Left
			horzRight = Svar.Right


		if (horzEdge.OutIdx >= 0 and op1 == nil)
			op1 = @GetLastOutPt(horzEdge)
			eNextHorz = @m_SortedEdges
			while (eNextHorz != nil)
				if (eNextHorz.OutIdx >= 0 and @HorzSegmentsOverlap(horzEdge.Bot.X, horzEdge.Top.X, eNextHorz.Bot.X, eNextHorz.Top.X))
					op2 = @GetLastOutPt(eNextHorz)
					@AddJoin(op2, op1, eNextHorz.Top)

				eNextHorz = eNextHorz.NextInSEL

			@AddGhostJoin(op1, horzEdge.Top)

		if (horzEdge.NextInLML != nil)
			if (horzEdge.OutIdx >= 0)
				op1 = @AddOutPt(horzEdge, horzEdge.Top)

				horzEdge = @UpdateEdgeIntoAEL(horzEdge)
				if (horzEdge.WindDelta == 0)
					return

				--nb: HorzEdge is no longer horizontal here
				ePrev = horzEdge.PrevInAEL
				eNext = horzEdge.NextInAEL

				if (ePrev != nil and ePrev.Curr.X == horzEdge.Bot.X and ePrev.Curr.Y == horzEdge.Bot.Y and ePrev.WindDelta == 0 and (ePrev.OutIdx >= 0 and ePrev.Curr.Y > ePrev.Top.Y and ClipperLib.ClipperBase.SlopesEqual(horzEdge, ePrev)))
					op2 = @AddOutPt(ePrev, horzEdge.Bot)
					@AddJoin(op1, op2, horzEdge.Top)

				elseif (eNext != nil and eNext.Curr.X == horzEdge.Bot.X and eNext.Curr.Y == horzEdge.Bot.Y and eNext.WindDelta != 0 and eNext.OutIdx >= 0 and eNext.Curr.Y > eNext.Top.Y and ClipperLib.ClipperBase.SlopesEqual(horzEdge, eNext))
					op2 = @AddOutPt(eNext, horzEdge.Bot)
					@AddJoin(op1, op2, horzEdge.Top)

			else
				horzEdge = @UpdateEdgeIntoAEL(horzEdge)

		else
			if (horzEdge.OutIdx >= 0)
				@AddOutPt(horzEdge, horzEdge.Top)
			@DeleteFromAEL(horzEdge)

	GetNextInAEL: (e, Direction) =>
		r = nil
		if Direction == ClipperLib.Direction.dLeftToRight
			r = e.NextInAEL
		else
			r = e.PrevInAEL

		return r

	IsMinima: (e) =>
		return e != nil and (e.Prev.NextInLML != e) and (e.Next.NextInLML != e)

	IsMaxima: (e, Y) =>
		return (e != nil and e.Top.Y == Y and e.NextInLML == nil)

	IsIntermediate: (e, Y) =>
		return (e.Top.Y == Y and e.NextInLML != nil)

	GetMaximaPair: (e) =>
		if ((ClipperLib.Point.op_Equality(e.Next.Top, e.Top)) and e.Next.NextInLML == nil)
			return e.Next
		else
			if ((ClipperLib.Point.op_Equality(e.Prev.Top, e.Top)) and e.Prev.NextInLML == nil)
				return e.Prev
			else
				return nil

	GetMaximaPairEx: (e) =>
		--as above but returns null if MaxPair isn't in AEL (unless it's horizontal)
		result = @GetMaximaPair(e)
		if (result == nil or result.OutIdx == ClipperLib.ClipperBase.Skip or ((result.NextInAEL == result.PrevInAEL) and not ClipperLib.ClipperBase.IsHorizontal(result)))
			return nil
		return result

	ProcessIntersections: (topY) =>
		if (@m_ActiveEdges == nil)
			return true

		@BuildIntersectList(topY)
		if (#@m_IntersectList == 0)
			return true
		if (#@m_IntersectList == 1 or @FixupIntersectionOrder())
			@ProcessIntersectList!
		else
			return false

		@m_SortedEdges = nil
		return true

	BuildIntersectList: (topY) =>
		if (@m_ActiveEdges == nil)
			return
		--prepare for sorting ...
		e = @m_ActiveEdges
		@m_SortedEdges = e
		while (e != nil)
			e.PrevInSEL = e.PrevInAEL
			e.NextInSEL = e.NextInAEL
			e.Curr.X = ClipperLib.Clipper.TopX(e, topY)
			e = e.NextInAEL

		--bubblesort ...
		isModified = true
		while (isModified and @m_SortedEdges != nil)
			isModified = false
			e = @m_SortedEdges
			while (e.NextInSEL != nil)
				eNext = e.NextInSEL
				pt = Point!
				if (e.Curr.X > eNext.Curr.X)
					@IntersectPoint(e, eNext, pt)
					if (pt.Y < topY)
						pt = Point(ClipperLib.Clipper.TopX(e, topY), topY)

					newNode = IntersectNode!
					newNode.Edge1 = e
					newNode.Edge2 = eNext

					newNode.Pt.X = pt.X
					newNode.Pt.Y = pt.Y

					table.insert(@m_IntersectList, newNode)
					@SwapPositionsInSEL(e, eNext)
					isModified = true

				else
					e = eNext

			if (e.PrevInSEL != nil)
				e.PrevInSEL.NextInSEL = nil
			else
				break

		@m_SortedEdges = nil

	EdgesAdjacent: (inode) =>
		return (inode.Edge1.NextInSEL == inode.Edge2) or (inode.Edge1.PrevInSEL == inode.Edge2)

	FixupIntersectionOrder: =>
		--pre-condition: intersections are sorted bottom-most first.
		--Now it's crucial that intersections are made only between adjacent edges,
		--so to ensure this the order of intersections may need adjusting ...

		Compare = (node1, node2) ->
			i = node2.Pt.Y - node1.Pt.Y
			return i < 0
		table.sort(@m_IntersectList, Compare)
		
		@CopyAELToSEL!
		cnt = #@m_IntersectList
		for i = 1, cnt
			if (not @EdgesAdjacent(@m_IntersectList[i]))
				j = i + 1
				while (j < cnt and not @EdgesAdjacent(@m_IntersectList[j]))
					j += 1
				if (j == cnt)
					return false
				tmp = @m_IntersectList[i]
				@m_IntersectList[i] = @m_IntersectList[j]
				@m_IntersectList[j] = tmp

			@SwapPositionsInSEL(@m_IntersectList[i].Edge1, @m_IntersectList[i].Edge2)

		return true

	ProcessIntersectList: =>
		for i = 1, #@m_IntersectList
			iNode = @m_IntersectList[i]
			@IntersectEdges(iNode.Edge1, iNode.Edge2, iNode.Pt)
			@SwapPositionsInAEL(iNode.Edge1, iNode.Edge2)

		@m_IntersectList = {}

	IntersectPoint: (edge1, edge2, ip) =>
		ip.X = 0
		ip.Y = 0
		b1 = nil
		b2 = nil
		--nb: with very large coordinate values, it's possible for SlopesEqual() to
		--return false but for the edge.Dx value be equal due to double precision rounding.
		if (edge1.Dx == edge2.Dx)
			ip.Y = edge1.Curr.Y
			ip.X = ClipperLib.Clipper.TopX(edge1, ip.Y)
			return

		if (edge1.Delta.X == 0)
			ip.X = edge1.Bot.X
			if (ClipperLib.ClipperBase.IsHorizontal(edge2))
				ip.Y = edge2.Bot.Y
			else
				b2 = edge2.Bot.Y - (edge2.Bot.X / edge2.Dx)
				ip.Y = ip.X / edge2.Dx + b2

		elseif (edge2.Delta.X == 0)
			ip.X = edge2.Bot.X
			if (ClipperLib.ClipperBase.IsHorizontal(edge1))
				ip.Y = edge1.Bot.Y
			else
				b1 = edge1.Bot.Y - (edge1.Bot.X / edge1.Dx)
				ip.Y = ip.X / edge1.Dx + b1

		else
			b1 = edge1.Bot.X - edge1.Bot.Y * edge1.Dx
			b2 = edge2.Bot.X - edge2.Bot.Y * edge2.Dx
			q = (b2 - b1) / (edge1.Dx - edge2.Dx)
			ip.Y = q
			if (math.abs(edge1.Dx) < math.abs(edge2.Dx))
				ip.X = edge1.Dx * q + b1
			else
				ip.X = edge2.Dx * q + b2

		if (ip.Y < edge1.Top.Y or ip.Y < edge2.Top.Y)
			if (edge1.Top.Y > edge2.Top.Y)
				ip.Y = edge1.Top.Y
				ip.X = ClipperLib.Clipper.TopX(edge2, edge1.Top.Y)
				return ip.X < edge1.Top.X
			else
				ip.Y = edge2.Top.Y
			if (math.abs(edge1.Dx) < math.abs(edge2.Dx))
				ip.X = ClipperLib.Clipper.TopX(edge1, ip.Y)
			else
				ip.X = ClipperLib.Clipper.TopX(edge2, ip.Y)

		--finally, don't allow 'ip' to be BELOW curr.Y (ie bottom of scanbeam) ...
		if (ip.Y > edge1.Curr.Y)
			ip.Y = edge1.Curr.Y
			--better to use the more vertical edge to derive X ...
			if (math.abs(edge1.Dx) > math.abs(edge2.Dx))
				ip.X = ClipperLib.Clipper.TopX(edge2, ip.Y)
			else
				ip.X = ClipperLib.Clipper.TopX(edge1, ip.Y)

	ProcessEdgesAtTopOfScanbeam: (topY) =>
		e = @m_ActiveEdges
		while (e != nil)
			--1. process maxima, treating them as if they're 'bent' horizontal edges,
			--but exclude maxima with horizontal edges. nb: e can't be a horizontal.
			IsMaximaEdge = @IsMaxima(e, topY)
			if (IsMaximaEdge)
				eMaxPair = @GetMaximaPairEx(e)
				IsMaximaEdge = (eMaxPair == nil or not ClipperLib.ClipperBase.IsHorizontal(eMaxPair))

			if (IsMaximaEdge)
				if (@StrictlySimple)
					@InsertMaxima(e.Top.X)
				ePrev = e.PrevInAEL
				@DoMaxima(e)
				if (ePrev == nil)
					e = @m_ActiveEdges
				else
					e = ePrev.NextInAEL

			else
				--2. promote horizontal edges, otherwise update Curr.X and Curr.Y ...
				if (@IsIntermediate(e, topY) and ClipperLib.ClipperBase.IsHorizontal(e.NextInLML))
					e = @UpdateEdgeIntoAEL(e)
					if (e.OutIdx >= 0)
						@AddOutPt(e, e.Bot)
					@AddEdgeToSEL(e)
				else
					e.Curr.X = ClipperLib.Clipper.TopX(e, topY)
					e.Curr.Y = topY

				--When StrictlySimple and 'e' is being touched by another edge, then
				--make sure both edges have a vertex here ...        
				if (@StrictlySimple)
					ePrev = e.PrevInAEL
					if ((e.OutIdx >= 0) and (e.WindDelta != 0) and ePrev != nil and (ePrev.OutIdx >= 0) and (ePrev.Curr.X == e.Curr.X) and (ePrev.WindDelta != 0))
						ip = Point(e.Curr)

						op = @AddOutPt(ePrev, ip)
						op2 = @AddOutPt(e, ip)
						@AddJoin(op, op2, ip) --StrictlySimple (type-3) join

				e = e.NextInAEL

		--3. Process horizontals at the Top of the scanbeam ...
		@ProcessHorizontals!
		@m_Maxima = nil
		--4. Promote intermediate vertices ...
		e = @m_ActiveEdges
		while (e != nil)
			if (@IsIntermediate(e, topY))
				op = nil
				if (e.OutIdx >= 0)
					op = @AddOutPt(e, e.Top)
				e = @UpdateEdgeIntoAEL(e)
				--if output polygons share an edge, they'll need joining later ...
				ePrev = e.PrevInAEL
				eNext = e.NextInAEL

				if (ePrev != nil and ePrev.Curr.X == e.Bot.X and ePrev.Curr.Y == e.Bot.Y and op != nil and ePrev.OutIdx >= 0 and ePrev.Curr.Y == ePrev.Top.Y and ClipperLib.ClipperBase.SlopesEqual(e.Curr, e.Top, ePrev.Curr, ePrev.Top) and (e.WindDelta != 0) and (ePrev.WindDelta != 0))
					op2 = @AddOutPt(ePrev2, e.Bot)
					@AddJoin(op, op2, e.Top)

				elseif (eNext != nil and eNext.Curr.X == e.Bot.X and eNext.Curr.Y == e.Bot.Y and op != nil and eNext.OutIdx >= 0 and eNext.Curr.Y == eNext.Top.Y and ClipperLib.ClipperBase.SlopesEqual(e.Curr, e.Top, eNext.Curr, eNext.Top) and (e.WindDelta != 0) and (eNext.WindDelta != 0))
					op2 = @AddOutPt(eNext, e.Bot)
					@AddJoin(op, op2, e.Top)

			e = e.NextInAEL

	DoMaxima: (e) =>
		eMaxPair = @GetMaximaPairEx(e)
		if (eMaxPair == nil)
			if (e.OutIdx >= 0)
				@AddOutPt(e, e.Top)
			@DeleteFromAEL(e)
			return

		eNext = e.NextInAEL
		while (eNext != nil and eNext != eMaxPair)
			@IntersectEdges(e, eNext, e.Top)
			@SwapPositionsInAEL(e, eNext)
			eNext = e.NextInAEL

		if (e.OutIdx == -1 and eMaxPair.OutIdx == -1)
			@DeleteFromAEL(e)
			@DeleteFromAEL(eMaxPair)

		elseif (e.OutIdx >= 0 and eMaxPair.OutIdx >= 0)
			if (e.OutIdx >= 0)
				@AddLocalMaxPoly(e, eMaxPair, e.Top)
			@DeleteFromAEL(e)
			@DeleteFromAEL(eMaxPair)

		elseif (ClipperLib.use_lines and e.WindDelta == 0)
			if (e.OutIdx >= 0)
				@AddOutPt(e, e.Top)
				e.OutIdx = ClipperLib.ClipperBase.Unassigned
			@DeleteFromAEL(e)

			if (eMaxPair.OutIdx >= 0)
				@AddOutPt(eMaxPair, e.Top)
				eMaxPair.OutIdx = ClipperLib.ClipperBase.Unassigned
			@DeleteFromAEL(eMaxPair)

		else
			ClipperLib.Error("DoMaxima error")

	PointCount: (pts) =>
		if (pts == nil)
			return 0
		result = 0
		p = pts

		while true do
			result += 1
			p = p.Next

			if p == pts
				break

		return result

	BuildResult: =>
		polyg = ClipperLib.Clear!
		for i = 1, #@m_PolyOuts
			outRec = @m_PolyOuts[i]
			if (outRec.Pts == nil)
				continue
			p = outRec.Pts.Prev
			cnt = @PointCount(p)
			if (cnt < 2)
				continue
			pg = {cnt}
			for j = 1, cnt
				pg[j] = p.Pt
				p = p.Prev
			table.insert(polyg, pg)

		@FinalSolution = polyg

	FixupOutPolyline: (outRec) =>
		pp = outRec.Pts
		lastPP = pp.Prev
		while (pp != lastPP)
			pp = pp.Next
			if (ClipperLib.Point.op_Equality(pp.Pt, pp.Prev.Pt))
				if (pp == lastPP)
					lastPP = pp.Prev
				tmpPP = pp.Prev
				tmpPP.Next = pp.Next
				pp.Next.Prev = tmpPP
				pp = tmpPP

		if (pp == pp.Prev)
			outRec.Pts = nil

	FixupOutPolygon: (outRec) =>
		--FixupOutPolygon() - removes duplicate points and simplifies consecutive
		--parallel edges by removing the middle vertex.
		lastOK = nil
		outRec.BottomPt = nil
		pp = outRec.Pts
		preserveCol = @PreserveCollinear or @StrictlySimple
		while true do
			if (pp.Prev == pp or pp.Prev == pp.Next)
				outRec.Pts = nil
				return

			--test for duplicate points and collinear edges ...
			if ((ClipperLib.Point.op_Equality(pp.Pt, pp.Next.Pt)) or (ClipperLib.Point.op_Equality(pp.Pt, pp.Prev.Pt)) or (ClipperLib.ClipperBase.SlopesEqual(pp.Prev.Pt, pp.Pt, pp.Next.Pt) and (not preserveCol or not @Pt2IsBetweenPt1AndPt3(pp.Prev.Pt, pp.Pt, pp.Next.Pt))))
				lastOK = nil
				pp.Prev.Next = pp.Next
				pp.Next.Prev = pp.Prev
				pp = pp.Prev
			elseif (pp == lastOK)
				break
			else
				if (lastOK == nil)
					lastOK = pp
				pp = pp.Next

		outRec.Pts = pp

	DupOutPt: (outPt, InsertAfter) =>
		result = OutPt!

		result.Pt.X = outPt.Pt.X
		result.Pt.Y = outPt.Pt.Y
		result.Idx = outPt.Idx

		if (InsertAfter)
			result.Next = outPt.Next
			result.Prev = outPt
			outPt.Next.Prev = result
			outPt.Next = result
		else
			result.Prev = outPt.Prev
			result.Next = outPt
			outPt.Prev.Next = result
			outPt.Prev = result

		return result

	GetOverlap: (a1, a2, b1, b2, Sval) =>
		if (a1 < a2)
			if (b1 < b2)
				Sval.Left = math.max(a1, b1)
				Sval.Right = math.min(a2, b2)
			else
				Sval.Left = math.max(a1, b2)
				Sval.Right = math.min(a2, b1)
		else
			if (b1 < b2)
				Sval.Left = math.max(a2, b1)
				Sval.Right = math.min(a1, b2)
			else
				Sval.Left = math.max(a2, b2)
				Sval.Right = math.min(a1, b1)

		return Sval.Left < Sval.Right

	JoinHorz: (op1, op1b, op2, op2b, Pt, DiscardLeft) =>
		Dir1 = nil
		Dir2 = nil

		if op1.Pt.X > op1b.Pt.X
			Dir1 = ClipperLib.Direction.dRightToLeft
		else
			Dir1 = ClipperLib.Direction.dLeftToRight

		if op2.Pt.X > op2b.Pt.X
			Dir2 = ClipperLib.Direction.dRightToLeft
		else
			Dir2 = ClipperLib.Direction.dLeftToRight

		if (Dir1 == Dir2)
			return false
		--When DiscardLeft, we want Op1b to be on the Left of Op1, otherwise we
		--want Op1b to be on the Right. (And likewise with Op2 and Op2b.)
		--So, to facilitate this while inserting Op1b and Op2b ...
		--when DiscardLeft, make sure we're AT or RIGHT of Pt before adding Op1b,
		--otherwise make sure we're AT or LEFT of Pt. (Likewise with Op2b.)
		if (Dir1 == ClipperLib.Direction.dLeftToRight)
			while (op1.Next.Pt.X <= Pt.X and op1.Next.Pt.X >= op1.Pt.X and op1.Next.Pt.Y == Pt.Y)
				op1 = op1.Next
			if (DiscardLeft and (op1.Pt.X != Pt.X))
				op1 = op1.Next
			op1b = @DupOutPt(op1, not DiscardLeft)
			if (ClipperLib.Point.op_Inequality(op1b.Pt, Pt))
				op1 = op1b
				op1.Pt.X = Pt.X
				op1.Pt.Y = Pt.Y

				op1b = @DupOutPt(op1, not DiscardLeft)
		else
			while (op1.Next.Pt.X >= Pt.X and op1.Next.Pt.X <= op1.Pt.X and op1.Next.Pt.Y == Pt.Y)
				op1 = op1.Next
			if (not DiscardLeft and (op1.Pt.X != Pt.X))
				op1 = op1.Next
			op1b = @DupOutPt(op1, DiscardLeft)
			if (ClipperLib.Point.op_Inequality(op1b.Pt, Pt))
				op1 = op1b
				op1.Pt.X = Pt.X
				op1.Pt.Y = Pt.Y

				op1b = @DupOutPt(op1, DiscardLeft)

		if (Dir2 == ClipperLib.Direction.dLeftToRight)
			while (op2.Next.Pt.X <= Pt.X and op2.Next.Pt.X >= op2.Pt.X and op2.Next.Pt.Y == Pt.Y)
				op2 = op2.Next
			if (DiscardLeft and (op2.Pt.X != Pt.X))
				op2 = op2.Next
			op2b = @DupOutPt(op2, not DiscardLeft)
			if (ClipperLib.Point.op_Inequality(op2b.Pt, Pt))
				op2 = op2b
				op2.Pt.X = Pt.X
				op2.Pt.Y = Pt.Y

				op2b = @DupOutPt(op2, not DiscardLeft)
		else
			while (op2.Next.Pt.X >= Pt.X and op2.Next.Pt.X <= op2.Pt.X and op2.Next.Pt.Y == Pt.Y)
				op2 = op2.Next
			if (not DiscardLeft and (op2.Pt.X != Pt.X))
				op2 = op2.Next
			op2b = @DupOutPt(op2, DiscardLeft)
			if (ClipperLib.Point.op_Inequality(op2b.Pt, Pt))
				op2 = op2b
				op2.Pt.X = Pt.X
				op2.Pt.Y = Pt.Y

				op2b = @DupOutPt(op2, DiscardLeft)

		if ((Dir1 == ClipperLib.Direction.dLeftToRight) == DiscardLeft)
			op1.Prev = op2
			op2.Next = op1
			op1b.Next = op2b
			op2b.Prev = op1b
		else
			op1.Next = op2
			op2.Prev = op1
			op1b.Prev = op2b
			op2b.Next = op1b

		return true

	JoinPoints: (j, outRec1, outRec2) =>
		op1 = j.OutPt1
		op1b = OutPt!
		op2 = j.OutPt2
		op2b = OutPt!
		--There are 3 kinds of joins for output polygons ...
		--1. Horizontal joins where Join.OutPt1 & Join.OutPt2 are vertices anywhere
		--along (horizontal) collinear edges (& Join.OffPt is on the same horizontal).
		--2. Non-horizontal joins where Join.OutPt1 & Join.OutPt2 are at the same
		--location at the Bottom of the overlapping segment (& Join.OffPt is above).
		--3. StrictlySimple joins where edges touch but are not collinear and where
		--Join.OutPt1, Join.OutPt2 & Join.OffPt all share the same point.
		isHorizontal = (j.OutPt1.Pt.Y == j.OffPt.Y)
		if (isHorizontal and (ClipperLib.Point.op_Equality(j.OffPt, j.OutPt1.Pt)) and (ClipperLib.Point.op_Equality(j.OffPt, j.OutPt2.Pt)))
			--Strictly Simple join ...
			if (outRec1 != outRec2)
				return false

			op1b = j.OutPt1.Next
			while (op1b != op1 and (ClipperLib.Point.op_Equality(op1b.Pt, j.OffPt)))
				op1b = op1b.Next
			reverse1 = (op1b.Pt.Y > j.OffPt.Y)
			op2b = j.OutPt2.Next
			while (op2b != op2 and (ClipperLib.Point.op_Equality(op2b.Pt, j.OffPt)))
				op2b = op2b.Next
			reverse2 = (op2b.Pt.Y > j.OffPt.Y)
			if (reverse1 == reverse2)
				return false
			if (reverse1)
				op1b = @DupOutPt(op1, false)
				op2b = @DupOutPt(op2, true)
				op1.Prev = op2
				op2.Next = op1
				op1b.Next = op2b
				op2b.Prev = op1b
				j.OutPt1 = op1
				j.OutPt2 = op1b
				return true
			else
				op1b = @DupOutPt(op1, true)
				op2b = @DupOutPt(op2, false)
				op1.Next = op2
				op2.Prev = op1
				op1b.Prev = op2b
				op2b.Next = op1b
				j.OutPt1 = op1
				j.OutPt2 = op1b
				return true

		elseif (isHorizontal)
			--treat horizontal joins differently to non-horizontal joins since with
			--them we're not yet sure where the overlapping is. OutPt1.Pt & OutPt2.Pt
			--may be anywhere along the horizontal edge.
			op1b = op1
			while (op1.Prev.Pt.Y == op1.Pt.Y and op1.Prev != op1b and op1.Prev != op2)
				op1 = op1.Prev
			while (op1b.Next.Pt.Y == op1b.Pt.Y and op1b.Next != op1 and op1b.Next != op2)
				op1b = op1b.Next
			if (op1b.Next == op1 or op1b.Next == op2)
				return false
			--a flat 'polygon'
			op2b = op2
			while (op2.Prev.Pt.Y == op2.Pt.Y and op2.Prev != op2b and op2.Prev != op1b)
				op2 = op2.Prev
			while (op2b.Next.Pt.Y == op2b.Pt.Y and op2b.Next != op2 and op2b.Next != op1)
				op2b = op2b.Next
			if (op2b.Next == op2 or op2b.Next == op1)
				return false
			--a flat 'polygon'
			--Op1 -. Op1b & Op2 -. Op2b are the extremites of the horizontal edges

			Sval = {
				Left: nil,
				Right: nil
			}

			if (not @GetOverlap(op1.Pt.X, op1b.Pt.X, op2.Pt.X, op2b.Pt.X, Sval))
				return false
			Left = Sval.Left
			Right = Sval.Right

			--DiscardLeftSide: when overlapping edges are joined, a spike will created
			--which needs to be cleaned up. However, we don't want Op1 or Op2 caught up
			--on the discard Side as either may still be needed for other joins ...
			Pt = Point!
			DiscardLeftSide = nil
			if (op1.Pt.X >= Left and op1.Pt.X <= Right)
				Pt.X = op1.Pt.X
				Pt.Y = op1.Pt.Y
				DiscardLeftSide = (op1.Pt.X > op1b.Pt.X)

			elseif (op2.Pt.X >= Left and op2.Pt.X <= Right)
				Pt.X = op2.Pt.X
				Pt.Y = op2.Pt.Y
				DiscardLeftSide = (op2.Pt.X > op2b.Pt.X)

			elseif (op1b.Pt.X >= Left and op1b.Pt.X <= Right)
				--Pt = op1b.Pt;
				Pt.X = op1b.Pt.X
				Pt.Y = op1b.Pt.Y
				DiscardLeftSide = op1b.Pt.X > op1.Pt.X

			else
				Pt.X = op2b.Pt.X
				Pt.Y = op2b.Pt.Y
				DiscardLeftSide = (op2b.Pt.X > op2.Pt.X)

			j.OutPt1 = op1
			j.OutPt2 = op2
			return @JoinHorz(op1, op1b, op2, op2b, Pt, DiscardLeftSide)

		else
			--nb: For non-horizontal joins ...
			--    1. Jr.OutPt1.Pt.Y == Jr.OutPt2.Pt.Y
			--    2. Jr.OutPt1.Pt > Jr.OffPt.Y
			--make sure the polygons are correctly oriented ...
			op1b = op1.Next
			while ((ClipperLib.Point.op_Equality(op1b.Pt, op1.Pt)) and (op1b != op1))
				op1b = op1b.Next

			Reverse1 = op1b.Pt.Y > op1.Pt.Y or not ClipperLib.ClipperBase.SlopesEqual(op1.Pt, op1b.Pt, j.OffPt)

			if (Reverse1)
				op1b = op1.Prev
				while ((ClipperLib.Point.op_Equality(op1b.Pt, op1.Pt)) and (op1b != op1))
					op1b = op1b.Prev

				if ((op1b.Pt.Y > op1.Pt.Y) or not ClipperLib.ClipperBase.SlopesEqual(op1.Pt, op1b.Pt, j.OffPt))

					return false

			op2b = op2.Next
			while ((ClipperLib.Point.op_Equality(op2b.Pt, op2.Pt)) and (op2b != op2))
				op2b = op2b.Next

			Reverse2 = op2b.Pt.Y > op2.Pt.Y or not ClipperLib.ClipperBase.SlopesEqual(op2.Pt, op2b.Pt, j.OffPt)

			if (Reverse2)
				op2b = op2.Prev
				while ((ClipperLib.Point.op_Equality(op2b.Pt, op2.Pt)) and (op2b != op2))
					op2b = op2b.Prev

				if ((op2b.Pt.Y > op2.Pt.Y) or not ClipperLib.ClipperBase.SlopesEqual(op2.Pt, op2b.Pt, j.OffPt))
					return false

			if ((op1b == op1) or (op2b == op2) or (op1b == op2b) or ((outRec1 == outRec2) and (Reverse1 == Reverse2)))
				return false

			if (Reverse1)
				op1b = @DupOutPt(op1, false)
				op2b = @DupOutPt(op2, true)
				op1.Prev = op2
				op2.Next = op1
				op1b.Next = op2b
				op2b.Prev = op1b
				j.OutPt1 = op1	
				j.OutPt2 = op1b
				return true
			else
				op1b = @DupOutPt(op1, true)
				op2b = @DupOutPt(op2, false)
				op1.Next = op2
				op2.Prev = op1
				op1b.Prev = op2b
				op2b.Next = op1b
				j.OutPt1 = op1
				j.OutPt2 = op1b
				return true

	GetBounds2: (ops) =>
		opStart = ops
		result = Rect!
		result.left = ops.Pt.X
		result.right = ops.Pt.X
		result.top = ops.Pt.Y
		result.bottom = ops.Pt.Y
		ops = ops.Next
		while (ops != opStart)
			if (ops.Pt.X < result.left)
				result.left = ops.Pt.X
			if (ops.Pt.X > result.right)
				result.right = ops.Pt.X
			if (ops.Pt.Y < result.top)
				result.top = ops.Pt.Y
			if (ops.Pt.Y > result.bottom)
				result.bottom = ops.Pt.Y
			ops = ops.Next

		return result

	PointInPolygon: (pt, op) =>
		--returns 0 if false, +1 if true, -1 if pt ON polygon boundary
		result = 0
		startOp = op
		ptx = pt.X
		pty = pt.Y
		poly0x = op.Pt.X
		poly0y = op.Pt.Y
		while true do
			op = op.Next
			poly1x = op.Pt.X
			poly1y = op.Pt.Y
			if (poly1y == pty)
				if ((poly1x == ptx) or (poly0y == pty and ((poly1x > ptx) == (poly0x < ptx))))
					return -1

			if ((poly0y < pty) != (poly1y < pty))
				if (poly0x >= ptx)
					if (poly1x > ptx)
						result = 1 - result
					else
						d = (poly0x - ptx) * (poly1y - pty) - (poly1x - ptx) * (poly0y - pty)
						if (d == 0)
							return -1
						if ((d > 0) == (poly1y > poly0y))
							result = 1 - result

				else
					if (poly1x > ptx)
						d = (poly0x - ptx) * (poly1y - pty) - (poly1x - ptx) * (poly0y - pty)
						if (d == 0)
							return -1
						if ((d > 0) == (poly1y > poly0y))
							result = 1 - result

			poly0x = poly1x
			poly0y = poly1y

			if (startOp == op)
				break

		return result

	Poly2ContainsPoly1: (outPt1, outPt2) =>
		op = outPt1
		while true do
			--nb: PointInPolygon returns 0 if false, +1 if true, -1 if pt on polygon
			res = @PointInPolygon(op.Pt, outPt2)
			if (res >= 0)
				return res > 0
			op = op.Next

			if (op == outPt1)
				break

		return true

	JoinCommonEdges: =>
		for i = 1, #@m_Joins
			join = @m_Joins[i]
			outRec1 = @GetOutRec(join.OutPt1.Idx)
			outRec2 = @GetOutRec(join.OutPt2.Idx)

			if (outRec1.Pts == nil or outRec2.Pts == nil)
				continue

			if (outRec1.IsOpen or outRec2.IsOpen)
				continue

			--get the polygon fragment with the correct hole state (FirstLeft)
			--before calling JoinPoints() ...
			holeStateRec = nil
			if (outRec1 == outRec2)
				holeStateRec = outRec1
			elseif (@OutRec1RightOfOutRec2(outRec1, outRec2))
				holeStateRec = outRec2
			elseif (@OutRec1RightOfOutRec2(outRec2, outRec1))
				holeStateRec = outRec1
			else
				holeStateRec = @GetLowermostRec(outRec1, outRec2)

			if (not @JoinPoints(join, outRec1, outRec2))
				continue

			if (outRec1 == outRec2)
				--instead of joining two polygons, we've just created a new one by
				--splitting one polygon into two.
				outRec1.Pts = join.OutPt1
				outRec1.BottomPt = nil
				outRec2 = @CreateOutRec!
				outRec2.Pts = join.OutPt2
				--update all OutRec2.Pts Idx's ...
				@UpdateOutPtIdxs(outRec2)

				if (@Poly2ContainsPoly1(outRec2.Pts, outRec1.Pts))
					--outRec1 contains outRec2 ...
					outRec2.IsHole = not outRec1.IsHole
					outRec2.FirstLeft = outRec1

					if  (BitXOR(outRec2.IsHole == true and 1 or 0, @ReverseSolution == true and 1 or 0)) == ((@AreaS1(outRec2) > 0) == true and 1 or 0)
						@ReversePolyPtLinks(outRec2.Pts)

				elseif (@Poly2ContainsPoly1(outRec1.Pts, outRec2.Pts))
					--outRec2 contains outRec1 ...
					outRec2.IsHole = outRec1.IsHole
					outRec1.IsHole = not outRec2.IsHole
					outRec2.FirstLeft = outRec1.FirstLeft
					outRec1.FirstLeft = outRec2

					if  (BitXOR(outRec1.IsHole == true and 1 or 0, @ReverseSolution == true and 1 or 0)) == ((@AreaS1(outRec1) > 0) == true and 1 or 0)
						@ReversePolyPtLinks(outRec1.Pts)

				else
					--the 2 polygons are completely separate ...
					outRec2.IsHole = outRec1.IsHole
					outRec2.FirstLeft = outRec1.FirstLeft

			else
				--joined 2 polygons together ...
				outRec2.Pts = nil
				outRec2.BottomPt = nil
				outRec2.Idx = outRec1.Idx
				outRec1.IsHole = holeStateRec.IsHole
				if (holeStateRec == outRec2)
					outRec1.FirstLeft = outRec2.FirstLeft
				outRec2.FirstLeft = outRec1

	UpdateOutPtIdxs: (outrec) =>
		op = outrec.Pts
		while true do
			op.Idx = outrec.Idx
			op = op.Prev
			
			if (op == outrec.Pts)
				break

	DoSimplePolygons: =>
		i = 1
		while (i <= #@m_PolyOuts)
			outrec = @m_PolyOuts[i]
			i += 1
			op = outrec.Pts
			if (op == nil or outrec.IsOpen)
				continue
			while true do --for each Pt in Polygon until duplicate found do ...
				op2 = op.Next
				while (op2 != outrec.Pts)
					if ((ClipperLib.Point.op_Equality(op.Pt, op2.Pt)) and op2.Next != op and op2.Prev != op)
						--split the polygon into two ...
						op3 = op.Prev
						op4 = op2.Prev
						op.Prev = op4
						op4.Next = op
						op2.Prev = op3
						op3.Next = op2
						outrec.Pts = op
						outrec2 = @CreateOutRec!
						outrec2.Pts = op2
						@UpdateOutPtIdxs(outrec2)
						if (@Poly2ContainsPoly1(outrec2.Pts, outrec.Pts))
							--OutRec2 is contained by OutRec1 ...
							outrec2.IsHole = not outrec.IsHole
							outrec2.FirstLeft = outrec
						elseif (@Poly2ContainsPoly1(outrec.Pts, outrec2.Pts))
							--OutRec1 is contained by OutRec2 ...
							outrec2.IsHole = outrec.IsHole
							outrec.IsHole = not outrec2.IsHole
							outrec2.FirstLeft = outrec.FirstLeft
							outrec.FirstLeft = outrec2
						else
							--the 2 polygons are separate ...
							outrec2.IsHole = outrec.IsHole
							outrec2.FirstLeft = outrec.FirstLeft
						op2 = op
						--ie get ready for the next iteration
					op2 = op2.Next
				op = op.Next

				if (op == outrec.Pts)
					break

	Area: (op) =>
		opFirst = op
		if (op == nil)
			return 0
		a = 0
		while true do
			a = a + (op.Prev.Pt.X + op.Pt.X) * (op.Prev.Pt.Y - op.Pt.Y)
			op = op.Next
			
			if(op == opFirst) -- and typeof op !== 'undefined')
				break

		return a * 0.5

	AreaS1: (outRec) =>
		return @Area(outRec.Pts)

ClipperLib.Clipper.SimplifyPolygons = (polys, fillType) ->
	c = Clipper!
	c.StrictlySimple = true
	c\AddPaths(polys, ClipperLib.PolyType.ptSubject, true)
	c\Execute(ClipperLib.ClipType.ctUnion, ClipperLib.PolyFillType.pftNonZero, ClipperLib.PolyFillType.pftNonZero)
	return c.FinalSolution

ClipperLib.ClipperOffset.GetUnitNormal = (pt1, pt2) ->
	if pt2.X == pt1.X and pt2.Y == pt1.Y
		return Point(0, 0)
	dx = (pt2.X - pt1.X)
	dy = (pt2.Y - pt1.Y)
	f = 1 / math.sqrt(dx*dx + dy*dy)
	dx *= f
	dy *= f
	return Point(dy, -dx)

class ClipperOffset
	new: (miterLimit, arcTolerance) =>
		@m_destPolys = Path!
		@m_srcPoly = Path!
		@m_destPoly = Path!
		@m_normals = {}
		@m_delta = 0
		@m_sinA = 0
		@m_sin = 0
		@m_cos = 0
		@m_miterLim = 0
		@m_StepsPerRad = 0
		@m_lowest = Point!
		@m_polyNodes = PolyNode!
		@MiterLimit = miterLimit or 2
		@ArcTolerance = arcTolerance or ClipperLib.ClipperOffset.def_arc_tolerance
		@m_lowest.X = -1

		@FinalSolution = nil

	Clear: =>
		ClipperLib.Clear(@m_polyNodes.Childs)
		@m_lowest.X = -1

	AddPath: (path, joinType, endType) =>
		highI = #path
		if (highI < 1)
			return
		newNode = PolyNode!
		newNode.m_jointype = joinType
		newNode.m_endtype = endType
		--strip duplicate points from path and also get index to the lowest point ...
		if (endType == ClipperLib.EndType.etClosedLine or endType == ClipperLib.EndType.etClosedPolygon)
			while (highI > 1 and ClipperLib.Point.op_Equality(path[1], path[highI]))
				highI -= 1

		table.insert(newNode.m_polygon, path[1])
		j = 1
		k = 1
		for i = 2, highI
			if (ClipperLib.Point.op_Inequality(newNode.m_polygon[j], path[i]))
				j += 1
				table.insert(newNode.m_polygon, path[i])
				if (path[i].Y > newNode.m_polygon[k].Y or (path[i].Y == newNode.m_polygon[k].Y and path[i].X < newNode.m_polygon[k].X))
					k = j

		if (endType == ClipperLib.EndType.etClosedPolygon and j < 3)
			return

		@m_polyNodes\AddChild(newNode)
		--if this path's lowest pt is lower than all the others then update m_lowest
		if (endType != ClipperLib.EndType.etClosedPolygon)
			return
		if (@m_lowest.X < 0)
			@m_lowest = Point(@m_polyNodes\ChildCount(), k)
		else
			ip = @m_polyNodes\Childs()[@m_lowest.X].m_polygon[@m_lowest.Y]
			if (newNode.m_polygon[k].Y > ip.Y or (newNode.m_polygon[k].Y == ip.Y and newNode.m_polygon[k].X < ip.X))
				@m_lowest = Point(@m_polyNodes\ChildCount(), k)

	AddPaths: (paths, joinType, endType) =>
		for i = 1, #paths
			@AddPath(paths[i], joinType, endType)

	FixOrientations: =>
		--fixup orientations of all closed paths if the orientation of the
		--closed path with the lowermost vertex is wrong ...
		if (@m_lowest.X >= 0 and not ClipperLib.Clipper.Orientation(@m_polyNodes\Childs()[@m_lowest.X].m_polygon))
			for i = 1, @m_polyNodes\ChildCount()
				node = @m_polyNodes\Childs()[i]
				if (node.m_endtype == ClipperLib.EndType.etClosedPolygon or (node.m_endtype == ClipperLib.EndType.etClosedLine and ClipperLib.Clipper.Orientation(node.m_polygon)))
					tempNode = {}
					for i = #node.m_polygon, 1, -1
						table.insert(tempNode, node.m_polygon[i])
					node.m_polygon = tempNode
		else
			for i = 1, @m_polyNodes\ChildCount()
				node = @m_polyNodes\Childs()[i]
				if (node.m_endtype == ClipperLib.EndType.etClosedLine and not ClipperLib.Clipper.Orientation(node.m_polygon))
					tempNode = {}
					for i = #node.m_polygon, 1, -1
						table.insert(tempNode, node.m_polygon[i])
					node.m_polygon = tempNode

	DoOffset: (delta) =>
		@m_destPolys = {}
		@m_delta = delta
		--if Zero offset, just copy any CLOSED polygons to m_p and return ...
		if (ClipperLib.ClipperBase.near_zero(delta))
			for i = 1, @m_polyNodes\ChildCount()
				node = @m_polyNodes\Childs()[i]
				if (node.m_endtype == ClipperLib.EndType.etClosedPolygon)
					table.insert(@m_destPolys, node.m_polygon)
			return

		--see offset_triginometry3.svg in the documentation folder ...
		if (@MiterLimit > 2)
			@m_miterLim = 2 / (@MiterLimit * @MiterLimit)
		else
			@m_miterLim = 0.5
		y = nil
		if (@ArcTolerance <= 0)
			y = ClipperLib.ClipperOffset.def_arc_tolerance
		elseif (@ArcTolerance > math.abs(delta) * ClipperLib.ClipperOffset.def_arc_tolerance)
			y = math.abs(delta) * ClipperLib.ClipperOffset.def_arc_tolerance
		else
			y = @ArcTolerance
		--see offset_triginometry2.svg in the documentation folder ...
		steps = 3.14159265358979 / math.acos(1 - y / math.abs(delta))
		@m_sin = math.sin(ClipperLib.ClipperOffset.two_pi / steps)
		@m_cos = math.cos(ClipperLib.ClipperOffset.two_pi / steps)
		@m_StepsPerRad = steps / ClipperLib.ClipperOffset.two_pi
		if (delta < 0)
			@m_sin = -@m_sin

		for i = 1, @m_polyNodes\ChildCount()
			node = @m_polyNodes\Childs()[i]


			@m_srcPoly = node.m_polygon
			len = #@m_srcPoly
			if (len == 0 or (delta <= 0 and (len < 3 or node.m_endtype != ClipperLib.EndType.etClosedPolygon)))
				continue
			@m_destPoly = {}
			if (len == 1)
				if (node.m_jointype == ClipperLib.JoinType.jtRound)
					X = 1
					Y = 0
					for j = 1, steps
						table.insert(@m_destPoly, Point(@m_srcPoly[1].X + X * delta, @m_srcPoly[1].Y + Y * delta))
						X2 = X
						X = X * @m_cos - @m_sin * Y
						Y = X2 * @m_sin + Y * @m_cos

				else
					X = -1
					Y = -1
					for j = 1, 4
						table.insert(@m_destPoly, Point(@m_srcPoly[1].X + X * delta, @m_srcPoly[1].Y + Y * delta))	
						if (X < 0)
							X = 1
						elseif (Y < 0)
							Y = 1
						else
							X = -1

				table.insert(@m_destPolys, @m_destPoly)
				continue

			--build m_normals ...
			@m_normals = {}
			for j = 1, len - 1
				table.insert(@m_normals, ClipperLib.ClipperOffset.GetUnitNormal(@m_srcPoly[j], @m_srcPoly[j + 1]))

			if (node.m_endtype == ClipperLib.EndType.etClosedLine or node.m_endtype == ClipperLib.EndType.etClosedPolygon)
				table.insert(@m_normals, ClipperLib.ClipperOffset.GetUnitNormal(@m_srcPoly[len], @m_srcPoly[1]))
			else
				table.insert(@m_normals, Point(@m_normals[len - 1]))

			if (node.m_endtype == ClipperLib.EndType.etClosedPolygon)
				k = len
				for j = 1, len
					k = @OffsetPoint(j, k, node.m_jointype)

				table.insert(@m_destPolys, @m_destPoly)

			elseif (node.m_endtype == ClipperLib.EndType.etClosedLine)
				k = len
				for j = 1, len
					k = @OffsetPoint(j, k, node.m_jointype)
				table.insert(@m_destPolys, @m_destPoly)
				@m_destPoly = {}
				--re-build m_normals ...
				n = @m_normals[len]
				for j = len, 2, -1
					@m_normals[j] = Point(-@m_normals[j - 1].X, -@m_normals[j - 1].Y)
				@m_normals[1] = Point(-n.X, -n.Y)
				k = 1
				for j = len, 1, -1
					k = @OffsetPoint(j, k, node.m_jointype)
				table.insert(@m_destPolys, @m_destPoly)

			else
				k = 1
				for j = 2, len - 1
					k = @OffsetPoint(j, k, node.m_jointype)
				pt1 = nil
				if (node.m_endtype == ClipperLib.EndType.etOpenButt)
					j = len
					pt1 = Point(@m_srcPoly[j].X + @m_normals[j].X * delta, @m_srcPoly[j].Y + @m_normals[j].Y * delta)
					table.insert(@m_destPoly, pt1)
					pt1 = Point(@m_srcPoly[j].X - @m_normals[j].X * delta, @m_srcPoly[j].Y - @m_normals[j].Y * delta)
					table.insert(@m_destPoly, pt1)
				else
					j = len
					k = len - 1
					@m_sinA = 0
					@m_normals[j] = Point(-@m_normals[j].X, -@m_normals[j].Y)
					if (node.m_endtype == ClipperLib.EndType.etOpenSquare)
						@DoSquare(j, k)
					else
						@DoRound(j, k)

				--re-build m_normals ...
				for j = len, 2, -1
					@m_normals[j] = Point(-@m_normals[j - 1].X, -@m_normals[j - 1].Y)
				@m_normals[1] = Point(-@m_normals[2].X, -@m_normals[2].Y)
				k = len
				for j = k - 1, 2, -1
					k = @OffsetPoint(j, k, node.m_jointype)
				if (node.m_endtype == ClipperLib.EndType.etOpenButt)
					pt1 = Point(@m_srcPoly[1].X - @m_normals[1].X * delta, @m_srcPoly[1].Y - @m_normals[1].Y * delta)
					table.insert(@m_destPoly, pt1)
					pt1 = Point(@m_srcPoly[1].X + @m_normals[1].X * delta, @m_srcPoly[1].Y + @m_normals[1].Y * delta)
					table.insert(@m_destPoly, pt1)
				else
					k = 1
					@m_sinA = 0
					if (node.m_endtype == ClipperLib.EndType.etOpenSquare)
						@DoSquare(1, 2)
					else
						@DoRound(1, 2)

				table.insert(@m_destPolys, @m_destPoly)

	Execute: (delta) =>
		@FixOrientations!
		@DoOffset(delta)
		-- now clean up 'corners' ...
		clpr = Clipper!
		clpr\AddPaths(@m_destPolys, ClipperLib.PolyType.ptSubject, true)
		if (delta > 0)
			clpr\Execute(ClipperLib.ClipType.ctUnion, ClipperLib.PolyFillType.pftPositive, ClipperLib.PolyFillType.pftPositive)
		else
			r = ClipperLib.Clipper.GetBounds(@m_destPolys)
			outer = Path!
			table.insert(outer, Point(r.left - 10, r.bottom + 10))
			table.insert(outer, Point(r.right + 10, r.bottom + 10))
			table.insert(outer, Point(r.right + 10, r.top - 10))
			table.insert(outer, Point(r.left - 10, r.top - 10))
			clpr\AddPath(outer, ClipperLib.PolyType.ptSubject, true)
			clpr.ReverseSolution = true
			clpr\Execute(ClipperLib.ClipType.ctUnion, ClipperLib.PolyFillType.pftNegative, ClipperLib.PolyFillType.pftNegative)
			
			if (#clpr.FinalSolution > 1)
				table.remove(clpr.FinalSolution, 1)

		@FinalSolution = clpr.FinalSolution

	OffsetPoint: (j, k, jointype) =>
		--cross product ...
		@m_sinA = (@m_normals[k].X * @m_normals[j].Y) - (@m_normals[j].X * @m_normals[k].Y)
		
		if @m_sinA == 0
			return k
		elseif (@m_sinA > 1)
			@m_sinA = 1
		elseif (@m_sinA < -1)
			@m_sinA = -1
		if (@m_sinA * @m_delta < 0)
			table.insert(@m_destPoly, Point(@m_srcPoly[j].X + @m_normals[k].X * @m_delta, @m_srcPoly[j].Y + @m_normals[k].Y * @m_delta))
			table.insert(@m_destPoly, Point(@m_srcPoly[j]))
			table.insert(@m_destPoly, Point(@m_srcPoly[j].X + @m_normals[j].X * @m_delta, @m_srcPoly[j].Y + @m_normals[j].Y * @m_delta))

		else
			switch (jointype)
				when ClipperLib.JoinType.jtMiter
						r = 1 + (@m_normals[j].X * @m_normals[k].X + @m_normals[j].Y * @m_normals[k].Y)
						if (r >= @m_miterLim)
							@DoMiter(j, k, r)
						else
							@DoSquare(j, k)

				when ClipperLib.JoinType.jtSquare
					@DoSquare(j, k)

				when ClipperLib.JoinType.jtRound
					@DoRound(j, k)

		k = j
		return k

	DoSquare: (j, k) =>
		dx = math.tan(math.atan2(@m_sinA, @m_normals[k].X * @m_normals[j].X + @m_normals[k].Y * @m_normals[j].Y) / 4)
		table.insert(@m_destPoly, Point(@m_srcPoly[j].X + @m_delta * (@m_normals[k].X - @m_normals[k].Y * dx), @m_srcPoly[j].Y + @m_delta * (@m_normals[k].Y + @m_normals[k].X * dx)))
		table.insert(@m_destPoly, Point(@m_srcPoly[j].X + @m_delta * (@m_normals[j].X + @m_normals[j].Y * dx), @m_srcPoly[j].Y + @m_delta * (@m_normals[j].Y - @m_normals[j].X * dx)))

	DoMiter: (j, k, r) =>
		q = @m_delta / r
		table.insert(@m_destPoly, Point(@m_srcPoly[j].X + (@m_normals[k].X + @m_normals[j].X) * q, @m_srcPoly[j].Y + (@m_normals[k].Y + @m_normals[j].Y) * q))
	
	DoRound: (j, k) =>
		a = math.atan2(@m_sinA, @m_normals[k].X * @m_normals[j].X + @m_normals[k].Y * @m_normals[j].Y)

		steps = math.max(@m_StepsPerRad * math.abs(a), 1)

		X = @m_normals[k].X
		Y = @m_normals[k].Y
		X2 = nil
		for i = 1, steps + 1
			table.insert(@m_destPoly, Point(@m_srcPoly[j].X + X * @m_delta, @m_srcPoly[j].Y + Y * @m_delta))
			X2 = X
			X = X * @m_cos - @m_sin * Y
			Y = X2 * @m_sin + Y * @m_cos

		table.insert(@m_destPoly, Point(@m_srcPoly[j].X + @m_normals[j].X * @m_delta, @m_srcPoly[j].Y + @m_normals[j].Y * @m_delta))

Aegihelp = {}

Aegihelp.Error = (log) ->
	aegisub.log(tostring(log) .. "\n\n")
	aegisub.cancel!

Aegihelp.Log = (log) ->
	aegisub.log(tostring(log) .. "\n\n")

Aegihelp.AegiToClipper = (clip) ->
	clip = Yutils.shape.flatten(clip)
	coord = {}
	part = {}
		
	for i in clip\gmatch("m ([^m]+)")
		table.insert(part, i)

	for i = 1, #part
		for x, y in part[i]\gmatch("([-%d.]+).([-%d.]+)")
			if coord[i] == nil then coord[i] = {}
			table.insert(coord[i], {X:tonumber(x), Y:tonumber(y)})

	return coord

Aegihelp.ClipperToAegi = (a) ->
	strs = {}
	str = ""
	for i = 1, #a
		str = str .. "m "
		for j = 1, #a[i]
			if j == 2
				str = str .. "l " .. Round(a[i][j].X) .. " " .. Round(a[i][j].Y) .. " "
			else
				str = str .. Round(a[i][j].X) .. " " .. Round(a[i][j].Y) .. " "

		table.insert(strs, str)
		str = ""

	str = ""
	for i = 1, #strs
		str = str .. strs[i]

	return str

Aegihelp.Move = (shape, horizontal, vertical) ->
	for i = 1, #shape
		for k = 1, #shape[i]
			shape[i][k].X += horizontal
			shape[i][k].Y += vertical

	return shape

Aegihelp.GetLine = (line) ->
	text, style = line.text, line.styleref

	clip = text\match '\\i?clip%b()'
	if clip != nil
		x1, y1, x2, y2 = clip\match '([%d.-]+),([%d.-]+),([%d.-]+),([%d.-]+)'
		if x1 != nil
			clip = "m #{x1} #{y1} l #{x2} #{y1} #{x2} #{y2} #{x1} #{y2}"
		else
			clip = clip\gsub('\\i?clip%(', '')\gsub('%)', '')

	local shape, words
	if text\match '^{[^}]-\\p1'
		shape = text\match '}([^{]+)'
		words = nil
	else
		shape = nil
		words = text\match '}([^{]+)'

	x, y = text\match '{[^}]-\\pos%(([%d.-]+),([%d.-]+)%)'
	x = tonumber(x) or line.x
	y = tonumber(y) or line.y

	org_x, org_y = text\match '{[^}]-\\org%(([%d.-]+),([%d.-]+)%)'
	org_x = tonumber(org_x) or x
	org_y = tonumber(org_y) or y

	getStr = (tag, default) -> text\match("{[^}]-\\#{tag}([^\\]+)") or default
	getNum = (tag, default) -> tonumber(text\match "{[^}]-\\#{tag}(%-?[0-9.]+)") or default
	getBool = (tag, default) -> switch text\match "{[^}]-\\#{tag}([01])"
		when '0' then false
		when '1' then true
		when nil then default
	getCol = (tag, default) ->
		c = text\match("{[^}]-\\#{tag}(&H%x+&)")
		if c == nil then c = default\gsub("&H..", "&H")
		return c

	return {
		:clip
		:shape
		family:    getStr  'fn',   style.fontname
		bold:      getBool 'b',    style.bold
		italic:    getBool 'i',    style.italic
		underline: getBool 'u',    style.underline
		strikeout: getBool 's',    style.strikeout
		size:      getNum  'fs',   style.fontsize
		xscale:    getNum  'fscx', style.scale_x
		yscale:    getNum  'fscy', style.scale_y
		hspace:    getNum  'fsp',  style.spacing
		frx:       getNum  'frx',  0
		fry:       getNum  'fry',  0
		frz:       getNum  'frz',  style.angle
		fax:       getNum  'fax',  0
		fay:       getNum  'fay',  0
		shad:      getNum  'shad', style.shadow
		bord:      getNum  'bord', style.outline
		blur:      getNum  'blur', 1
		text: words
		pos: {:x, :y}
		org: {x:org_x, y:org_y}
		color1:    getCol  'c',    style.color1
		color2:    getCol  '2c',   style.color2
		color3:    getCol  '3c',   style.color3
		color4:    getCol  '4c',   style.color4
	}

Aegihelp.TextToShape = (data) ->
	--what a mess this is, yutils move the generated shapes in a weird way that i don't understand
	--i'll get back to this
	if data.text == nil
		Aegihelp.Log("There is no text in the line")
	
	font = Yutils.decode.create_font(data.family, data.bold, data.italic, data.underline, data.strikeout, data.size, data.xscale / 100, data.yscale / 100, data.hspace)
	textshape = font.text_to_shape(data.text)
	metrics = font.metrics()
	extents = font.text_extents(data.text)
	extents1 = Yutils.decode.create_font(data.family, data.bold, data.italic, data.underline, data.strikeout, data.size * data.xscale / 100, 1, 1, data.hspace).text_extents(data.text)
	data.shape = Aegihelp.Move(Aegihelp.AegiToClipper(textshape), -(tonumber(extents1.width/2)), -(tonumber(extents.height/2)))
	data.xscale, data.yscale = 100, 100
	return data.shape

Aegihelp.FindCenter = (shape) ->
	shape = Yutils.shape.flatten(shape)
	points = {}
	for x, y in shape\gmatch("([-%d.]+).([-%d.]+)")
		table.insert(points, {x: tonumber(x), y: tonumber(y)})

	topX = points[1].x
	topY = points[1].y
	bottomX = points[1].x
	bottomY = points[1].y

	for point in *points
		if point.x > topX
			topX = point.x
		elseif point.x < bottomX
			bottomX = point.x

		if point.y > topY
			topY = point.y
		elseif point.y < bottomY
			bottomY = point.y

	return {x: ((topX - bottomX) / 2) + bottomX, y: ((topY - bottomY) / 2) + bottomY}

Aegihelp.Expand = (data) ->
	points = data.shape

	if type(data.shape) != "table"
		points = Aegihelp.AegiToClipper(data.shape)

	--copied from libass calc_transformation_matrix
	frx = math.pi / 180 * data.frx
	fry = math.pi / 180 * data.fry
	frz = math.pi / 180 * data.frz

	sx, cx = -math.sin(frx), math.cos(frx)
	sy, cy =  math.sin(fry), math.cos(fry)
	sz, cz = -math.sin(frz), math.cos(frz)

	xscale = data.xscale / 100
	yscale = data.yscale / 100

	fax = data.fax * data.xscale / data.yscale
	fay = data.fay * data.yscale / data.xscale
	x1 = {1, fax, data.pos.x - data.org.x}
	y1 = {fay, 1, data.pos.y - data.org.y}

	x2, y2 = {}, {}
	for i = 1, 3
		x2[i] = x1[i] * cz - y1[i] * sz
		y2[i] = x1[i] * sz + y1[i] * cz

	y3, z3 = {}, {}
	for i = 1, 3
		y3[i] = y2[i] * cx
		z3[i] = y2[i] * sx

	x4, z4 = {}, {}
	for i = 1, 3
		x4[i] = x2[i] * cy - z3[i] * sy
		z4[i] = x2[i] * sy + z3[i] * cy

	dist = 312.5
	z4[3] += dist

	offs_x = data.org.x - data.pos.x
	offs_y = data.org.y - data.pos.y

	m = {}
	m[1], m[2], m[3] = {}, {}, {}
	for i = 1, 3
		m[1][i] = z4[i] * offs_x + x4[i] * dist
		m[2][i] = z4[i] * offs_y + y3[i] * dist
		m[3][i] = z4[i]

	--copied from libass outline_transform_3d
	--when there's extreme perspective this doesn't work, i'll come back to this later
	for i = 1, #points
		for k = 1, #points[i]
			v = {}
			for j = 1, 3
				v[j] = (m[j][1] * points[i][k].X * xscale) + (m[j][2] * points[i][k].Y * yscale) + m[j][3] 

			w = 1 / math.max(v[3], 0.1)
			points[i][k].X = Round(v[1] * w, 2)
			points[i][k].Y = Round(v[2] * w, 2)

	return points

GUI = {
	main: {
		{class: "label", label: "Pathfinder", x: 1, y: 0},
		{class: "dropdown", name: "pathfinder", value: "Union", items: {"Union", "Intersect", "Difference", "XOR"}, x: 0, y: 0},
		{class: "dropdown", name: "filltype", value: "NonZero", items: {"NonZero", "EvenOdd"}, x: 0, y: 1},
		{class: "label", label: "FillType", x: 1, y: 1},
		{class: "checkbox", label: "Multiline", name: "multiline", value: false, x: 0, y: 2, width: 1, height: 1},

		{class: "label", label: "Offsetting", x: 0, y: 6},
		{class: "floatedit", name: "delta", x: 1, y: 6, width: 1, height: 1, hint: "delta", value: 0},
		{class: "dropdown", name: "endtype", value: "ClosedPolygon", items: {"ClosedPolygon", "ClosedLine"}, x: 0, y: 7},
		{class: "label", label: "EndType", x: 0, y: 8},
		{class: "dropdown", name: "jointype", value: "Miter", items: {"Miter", "Round", "Square"}, x: 1, y: 7},
		{class: "label", label: "JoinType", x: 1, y: 8},
		{class: "floatedit", name: "miterLimit", x: 0, y: 9, width: 1, height: 1, hint: "miterLimit", value: 2},
		{class: "floatedit", name: "arcTolerance", x: 1, y: 9, width: 1, height: 1, hint: "arcTolerance", value: 0.25},


		{class: "label", label: "Others", x: 6, y: 0},
		{class: "dropdown", name: "others", value: "Text to Shape", items: {"Text to Shape", "Move Shape", "Inner Shadow", "Center Shape"}, x: 6, y: 1},
		{class: "checkbox", label: "Convert", name: "convert", value: false, x: 6, y: 2, width: 1, height: 1},
		{class: "label", label: "Horizontal:", x: 7, y: 0},
		{class: "floatedit", name: "horizontal", x: 7, y: 1, width: 1, height: 1},
		{class: "label", label: "Vertical:", x: 7, y: 2, width: 1, height: 1},
		{class: "floatedit", name: "vertical", x: 7, y: 3, width: 1, height: 1},


		{class: "label", label: "Gradient Step (2 min)", x: 6, y: 6},
		{class: "floatedit", name: "gradientsize", x: 6, y: 7, width: 1, height: 1, hint: "Gradient size", value: 2},
		{class: "checkbox", label: "Continue gradient", name: "extendgradient", value: false, x: 6, y: 8, width: 1, height: 1},

		{class: "label", label: "ver: " .. script_version, x: 7, y: 9}
	},
	help: {
		{class: "textbox", x: 0, y: 0, width: 45, height: 15, value: Helptext}
	},
	config: {
		{class: "label", label: "Coming soon", x: 0, y: 0}
	}
}

local SUBTITLES, SELECTED_LINE, ACTIVE_LINE

Shapery = {}

Shapery.Main = (sub, sel) ->
	SUBTITLES, SELECTED_LINE = sub, sel
	run, res = aegisub.dialog.display(GUI.main, {"Pathfinder", "Offsetting", "Others", "Gradient", "Help", "Exit"}, {close: "Exit"})

	if run == "Help"
		Shapery.Help!

	meta, styles = karaskel.collect_head sub, false

	for si, li in ipairs(sel)
		line = sub[li]
		karaskel.preproc_line sub, meta, styles, line
		data = Aegihelp.GetLine(line)

		ft = res.filltype == "NonZero" and ClipperLib.PolyFillType.pftNonZero or ClipperLib.PolyFillType.pftEvenOdd

		if run == "Pathfinder"
			cpr = Clipper!

			line_number = 0
			if not res.multiline
				if data.clip == nil
					Aegihelp.Error("\\clip missing from line")
				
				data.clip = data.clip\gsub("clip%(", "")\gsub("%)", "")
				data.clip = Aegihelp.Move(Aegihelp.AegiToClipper(data.clip), -data.pos.x, -data.pos.y)
				
				cpr\AddPaths(Aegihelp.AegiToClipper(data.shape), ClipperLib.PolyType.ptSubject, true)
				cpr\AddPaths(data.clip, ClipperLib.PolyType.ptClip, true)

			else
				commonpos = nil
				for tmp_si, tmp_li in ipairs(sel)
					tmp_line = sub[tmp_li]
					karaskel.preproc_line sub, meta, styles, tmp_line
					tmp_data = Aegihelp.GetLine(tmp_line)
					if line_number == 0
						commonpos = tmp_data.pos
						cpr\AddPaths(Aegihelp.AegiToClipper(tmp_data.shape), ClipperLib.PolyType.ptSubject, true)
						line_number += 1
						tmp_line.comment = true
						sub[tmp_li] = tmp_line
						continue
					if commonpos != tmp_data.pos
						tmp_data.shape = Aegihelp.Move(Aegihelp.AegiToClipper(tmp_data.shape), tmp_data.pos.x - commonpos.x, tmp_data.pos.y - commonpos.y)
						cpr\AddPaths(tmp_data.shape, ClipperLib.PolyType.ptClip, true)
					else
						cpr\AddPaths(Aegihelp.AegiToClipper(tmp_data.shape), ClipperLib.PolyType.ptClip, true)
					line_number += 1
					tmp_line.comment = true
					sub[tmp_li] = tmp_line

			switch res.pathfinder
				when "Union"      then cpr\Execute(ClipperLib.ClipType.ctUnion, ft, ft)
				when "Intersect"  then cpr\Execute(ClipperLib.ClipType.ctIntersection, ft, ft)
				when "Difference" then cpr\Execute(ClipperLib.ClipType.ctDifference, ft, ft)
				when "XOR"        then cpr\Execute(ClipperLib.ClipType.ctXor, ft, ft)

			line.text = line.text\gsub("\\i?clip%b()", "")\match("%b{}") .. Aegihelp.ClipperToAegi(cpr.FinalSolution)

			if res.multiline
				sub.insert(li + line_number, line)
				break
			else
				sub[li] = line

		if run == "Offsetting"
			if data.shape == nil
				Aegihelp.Error("Shape missing")

			local jt, et

			switch res.jointype
				when "Miter"  then jt = ClipperLib.JoinType.jtMiter 
				when "Round"  then jt = ClipperLib.JoinType.jtRound
				when "Square" then jt = ClipperLib.JoinType.jtSquare

			switch res.endtype
				when "ClosedPolygon" then et = ClipperLib.EndType.etClosedPolygon
				when "ClosedLine"    then et = ClipperLib.EndType.etClosedLine

			shape = ClipperLib.Clipper.SimplifyPolygons(Aegihelp.AegiToClipper(data.shape), ClipperLib.Clipper.pftNonZero)

			co = ClipperOffset(res.miterLimit, res.arcTolerance)
			co\AddPaths(shape, jt, et)
			co\Execute(res.delta)

			line.text = line.text\match("%b{}") .. Aegihelp.ClipperToAegi(co.FinalSolution)

			sub[li] = line

		if run == "Others"
			if res.others == "Text to Shape"
				if data.text == nil
					Aegihelp.Error("Text missing")

				if data.fax != 0 or data.fay != 0
					Aegihelp.Log("\\fax and \\fay might cause wrong results")

				shape = Aegihelp.TextToShape(data)

				line.comment = true
				sub[li] = line
				line.comment = false

				line.text = line.text\match("%b{}")\gsub("\\an[%d%.%-]+", "")\gsub("\\fscx[%d%.%-]+", "")\gsub("\\fscy[%d%.%-]+", "")\gsub("}", "\\an7\\p1}")\gsub("\\fn[^\\]+", "") .. Aegihelp.ClipperToAegi(shape)
				sub.insert(li + 1, line)

			if res.others == "Move Shape"
				if data.shape == nil
					Aegihelp.Error("Shape missing")
				shape = Aegihelp.Move(Aegihelp.AegiToClipper(data.shape), res.horizontal, res.vertical)
				line.text = line.text\match("%b{}") .. Aegihelp.ClipperToAegi(shape)
				sub[li] = line

			if res.others == "Inner Shadow"
				if data.shape == nil
					Aegihelp.Error("Shape missing")
				sub[li] = line

				line.layer += 1

				cpr = Clipper!
				shape = Aegihelp.AegiToClipper(data.shape)
				cpr\AddPaths(shape, ClipperLib.PolyType.ptSubject, true)
				cpr\AddPaths(Aegihelp.Move(shape, res.horizontal, res.vertical), ClipperLib.PolyType.ptClip, true)

				cpr\Execute(ClipperLib.ClipType.ctDifference, ft, ft)

				line.text = line.text\match("%b{}") .. Aegihelp.ClipperToAegi(cpr.FinalSolution)
				sub.insert(li + 1, line)

			if res.others == "Center Shape"
				if data.shape == nil
					Aegihelp.Error("Shape missing")
				center = Aegihelp.FindCenter(data.shape)
				shape = Aegihelp.Move(Aegihelp.AegiToClipper(data.shape), -center.x, -center.y)
				line.text = line.text\match("%b{}") .. Aegihelp.ClipperToAegi(shape)
				sub[li] = line

		if run == "Gradient"
			if res.gradientsize < 2
				res.gradientsize = 2
			split_line = (clip) ->
				x0, y0, x1, y1 = clip\match("m ([%d.-]+) ([%d.-]+) l ([%d.-]+) ([%d.-]+)")
				max_len = res.gradientsize
				rel_x, rel_y = x1 - x0, y1 - y0
				distance = math.sqrt(rel_x*rel_x + rel_y*rel_y)
				points = {}
				if distance > max_len
					lines, distance_rest = {}, distance % max_len
					cur_distance = distance_rest > 0 and distance_rest or max_len
					
					while cur_distance <= distance
						pct = cur_distance / distance
						table.insert(points, {Round(x0 + rel_x * pct, 2), Round(y0 + rel_y * pct, 2)})
						cur_distance += max_len

					extreme_val = 65536
					extremes = {
						{x: rel_x * -extreme_val, y: rel_y * -extreme_val},
						{x: rel_x * extreme_val, y: rel_y * extreme_val},
					}

					return points, extremes

			find_perpendicular_points = (p1, p2, distance) ->
				x1, y1, x2, y2 = p1[1], p1[2], p2[1], p2[2]
				dx = x2-x1
				dy = y2-y1

				mx = (x2+x1)/2
				my = (y2+y1)/2

				L = math.sqrt(dx * dx + dy * dy)

				U = {x: -dy / L, y: dx / L}

				x = mx + U.x * distance
				y = my + U.y * distance
				xx = mx - U.x * distance
				yy = my - U.y * distance
				
				return {{:x, :y}, {x:xx, y:yy}}

			make_gradient_seg = (p, radius, extreme_a, extreme_b) ->
				radius = math.abs(radius)
				p1, p2 = p[1], p[2]
				dy = p2.y - p1.y
				dx = p2.x - p1.x
				angle = math.atan2 dy, dx
				perp_angle = angle + math.pi / 2
				ox = radius * math.cos perp_angle
				oy = radius * math.sin perp_angle

				p1a = {x: p1.x - ox, y: p1.y - oy}
				p1b = {x: p1.x + ox, y: p1.y + oy}
				p2a = {x: p2.x - ox, y: p2.y - oy}
				p2b = {x: p2.x + ox, y: p2.y + oy}

				if extreme_a != nil
					p1a = extreme_a
					p2a = extreme_a
				if extreme_b != nil
					p1b = extreme_b
					p2b = extreme_b

				return string.format(
					"m %f %f l %f %f %f %f %f %f",
					Round(p1a.x, 4), Round(p1a.y, 4),
					Round(p1b.x, 4), Round(p1b.y, 4),
					Round(p2b.x, 4), Round(p2b.y, 4),
					Round(p2a.x, 4), Round(p2a.y, 4)
				)

			split, extremes = split_line(Aegihelp.GetLine(line).clip)--data.clip)

			perp_line = {}
			for i = 1, #split - 1
				table.insert(perp_line, find_perpendicular_points(split[i], split[i + 1], 2000))

			if res.gradientsize <= 1 then res.gradientsize = 1

			perp_lines_expanded = {}
			for i, line in ipairs perp_line
				local extreme_a, extreme_b
				if res.extendgradient
					if i == 1
						extreme_a = extremes[1]
					if i == #perp_line
						extreme_b = extremes[2]
				segment_clip = make_gradient_seg line, res.gradientsize * 1.5, extreme_a, extreme_b
				table.insert(perp_lines_expanded, segment_clip)

			--creazione colori
			class RGB
				new: (r, g, b) =>
					@r = r or 0
					@g = g or 0
					@b = b or 0

			interpolate = (start_c, end_c, num, result) ->
				b2s = (b) -> if b then 1 else -1

				red = math.abs(start_c.r - end_c.r) / (num - 2)
				invert_red = b2s(start_c.r <= end_c.r)

				green = math.abs(start_c.g - end_c.g) / (num - 2)
				invert_green = b2s(start_c.g <= end_c.g)

				blue = math.abs(start_c.b - end_c.b) / (num - 2)
				invert_blue = b2s(start_c.b <= end_c.b)

				current_c = RGB()
				for i = 1, num
					if i == 1
						current_c = start_c
					elseif i == num
						current_c = end_c
					else
						current_c.r += red * invert_red
						current_c.g += green * invert_green
						current_c.b += blue * invert_blue

					color_string = ass_color(current_c.r, current_c.g, current_c.b)
					table.insert(result, "\\c" .. color_string)

				return result

			col = {}
			for i = 0, #sel - 1
				clrline = sub[li + i]
				color_string = clrline.text\match("^{[^}]-\\c([^})\\]+)") or "&HFFFFFF&"
				r, g, b = extract_color color_string
				table.insert(col, RGB(r, g, b))

			lines_per_color = Round(#perp_lines_expanded / (#col - 1), 0)
			risultato_colori = {}
			amount = lines_per_color
			for i = 1, #col - 1
				if i == #col - 1
					if amount != #perp_lines_expanded
						lines_per_color = #perp_lines_expanded - amount + lines_per_color
						risultato_colori = interpolate(col[i], col[i + 1], lines_per_color, risultato_colori)
					else
						risultato_colori = interpolate(col[i], col[i + 1], lines_per_color, risultato_colori)
				else
					risultato_colori = interpolate(col[i], col[i + 1], lines_per_color, risultato_colori)
					amount += lines_per_color

			i2 = 0
			for i = 1, #perp_lines_expanded
				cpr = Clipper!
				cpr\AddPaths(Aegihelp.AegiToClipper(data.shape), ClipperLib.PolyType.ptSubject, true)
				--cpr\AddPaths(Aegihelp.AegiToClipper(perp_lines_expanded[i]), ClipperLib.PolyType.ptClip, true)
				cpr\AddPaths(Aegihelp.Move(Aegihelp.AegiToClipper(perp_lines_expanded[i]), -data.pos.x, -data.pos.y), ClipperLib.PolyType.ptClip, true)

				cpr\Execute(ClipperLib.ClipType.ctIntersection, ft, ft)
				solution_paths = Aegihelp.ClipperToAegi(cpr.FinalSolution)
				gradline = line
				gradline.text = line.text\match("%b{}")
				gradline.text = gradline.text\gsub("\\i?clip%b()", "")\gsub("\\c&H......&", "")\gsub("{", "{" .. risultato_colori[i]) .. Aegihelp.ClipperToAegi(cpr.FinalSolution)
				
				if Aegihelp.GetLine(gradline).shape == nil
					continue
				sub.insert(li + i2 + #col, gradline)
				i2 += 1


			--comment all the other lines
			for i = 0, #col - 1
				line = sub[li + i]
				line.comment = true
				sub[li + i] = line
			break

Shapery.Help = ->
	run, res = aegisub.dialog.display(GUI.help, {"Shapery", "Config", "Update", "Exit"}, {close: "Exit"})
	if run == "Shapery"
		Shapery.Main(SUBTITLES, SELECTED_LINE)
	if run == "Config"
		Shapery.Config!
	if run == "Update"
		if haveDepCtrl
			macro = {
				feed: "https://raw.githubusercontent.com/Alendt/Aegisub-Scripts/master/DependencyControl.json"
				version: script_version,
				lastUpdateCheck: nil,
				requiredModules: {},
				namespace: script_namespace,
				configFile: "",
				channels: "master",
				lastChannel: "",
				release: "",
				name: "Shapery",
				author: "Alen"
			}
			task, err = DependencyControl.updater\addTask macro, nil, nil, false, macro.channels
			if task then task\run!
			else logger\log err
		else
			Aegihelp.Error("You need DependencyControl to update the script automatically.")

Shapery.Config = ->
	run, res = aegisub.dialog.display(GUI.config, {"Shapery", "Help", "Exit"}, {close: "Exit"})
	if run == "Shapery"
		Shapery.Main(SUBTITLES, SELECTED_LINE)
	if run == "Help"
		Shapery.Help!

Macros = {}

Macros.ClipToShape = (sub, sel) ->
	meta, styles = karaskel.collect_head sub, false
	for si, li in ipairs(sel)
		line = sub[li]
		karaskel.preproc_line sub, meta, styles, line
		data = Aegihelp.GetLine(line)

		if data.clip == nil
			Aegihelp.Error("\\clip missing")

		line.text = "{\\an7\\bord0\\shad0\\fscx100\\fscy100\\pos(0,0)\\p1}"\gsub("\\an7", "\\an7\\blur" .. data.blur) .. data.clip

		sub[li] = line

Macros.ShapeToClip = (sub, sel) ->
	meta, styles = karaskel.collect_head sub, false
	for si, li in ipairs(sel)
		line = sub[li]
		karaskel.preproc_line sub, meta, styles, line
		data = Aegihelp.GetLine(line)

		shape = data.shape
		if shape == nil
			Aegihelp.Error("Shape missing")

		if data.pos.x != 0 or data.pos.y != 0
			contour = Aegihelp.AegiToClipper(shape)
			contour = Aegihelp.Move(contour, data.pos.x, data.pos.y)
			shape = Aegihelp.ClipperToAegi(contour)

		-- don't match clips containing commas
		-- a clip with commas is a rectangular clip
		-- we don't want to overwrite rectangular clips
		line.text = line.text\gsub("\\i?clip%([^),]*%)", "")
		line.text = line.text\gsub("}", "\\clip(#{shape})}")

		sub[li] = line

Macros.Expand = (sub, sel) ->
	meta, styles = karaskel.collect_head sub, false
	for si, li in ipairs(sel)
		line = sub[li]
		karaskel.preproc_line sub, meta, styles, line
		data = Aegihelp.GetLine(line)

		if data.shape == nil
			Aegihelp.Error("There is nothing to expand")

		if data.fax != 0 or data.fay != 0
			line.text = line.text\gsub("\\fax[%d%.%-]+", "")\gsub("\\fay[%d%.%-]+", "")
		if data.xscale != 100 or data.yscale != 100
			line.text = line.text\gsub("\\fscx[%d%.%-]+", "")\gsub("\\fscy[%d%.%-]+", "")
		if data.frz != 0 or data.fry != 0 or data.frx != 0
			line.text = line.text\gsub("\\frz[%d%.%-]+", "")\gsub("\\frx[%d%.%-]+", "")\gsub("\\fry[%d%.%-]+", "")
		line.text = line.text\gsub("\\org%b()", "") if line.text\match("\\org%b()")
		line.text = line.text\match("%b{}") .. Aegihelp.ClipperToAegi(Aegihelp.Expand(data))

		sub[li] = line

if haveDepCtrl
	depctrl\registerMacros({
		{script_name, script_description, Shapery.Main},
		{": Shapery macros :/Clip To Shape", "Convert clip to shape", Macros.ClipToShape},
		{": Shapery macros :/Shape To Clip", "Convert shape to clip", Macros.ShapeToClip},
		{": Shapery macros :/Expand", "", Macros.Expand}
	}, false)
else
	aegisub.register_macro(script_name, script_description, Shapery.Main)
	aegisub.register_macro(": Shapery macros :/Clip To Shape", "Convert clip to shape", Macros.ClipToShape)
	aegisub.register_macro(": Shapery macros :/Shape To Clip", "Convert shape to clip", Macros.ShapeToClip)
	aegisub.register_macro(": Shapery macros :/Expand", "", Macros.Expand)
