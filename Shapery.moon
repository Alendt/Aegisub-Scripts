export script_name = "Shapery"
export script_description = "Try to emulate the most used tools of Illustrator."
export script_author = "Alen"
export script_version = "1.0.0"

Helptext = "====== Comment and credits ======
I'm not a programmer, most of the code is just a 1:1 copy from somewhere rewrote in moonscript.
I do this only as a hobby and for fun. Don't get mad if the code is bad :)

This automation is based from this library http://www.angusj.com/delphi/clipper.php.
Actually I used the javascript version which you can find here https://sourceforge.net/projects/jsclipper/
I used the javascript version as the base because c++ and such are just too hard for me to understand.

If you find bugs or the results you are getting are wrong, please report them. Advices and ideas are welcome. (Check the TO-DO list before maybe)
Be carefull with what you do. If you are doing something with complex shapes, you should save your script before running this automation.
If you want to contact me to give advices or anything, you can do it on discord Alen#4976

====== Pathfinder ======
Given 2 polygons in the form of shape and clip, the automation will perform the selected operation between them.

-Union: the result will be an union between the shape and the clip.
-Difference: the result will be the the shape minus the clip.
-Intersect: the result will be a polygon composed by the part where both shape and clip are present.
-XOR: the opposite of intersect (maybe? lol)

It is possible to chose the filling rule of the 2 polygons (shape and clip) separately.
I don't know if these is even useful tbh.
Look it up online for the difference or just use NonZero.

====== Offsetting ======
Inflating and deflating polygons.
The angles can have 3 style: miter, round and square.
The arc tolerance define the precision a curve will have if the style Round is used.
This is super bugged right now (for example https://i.imgur.com/hhXeYgh.png . Even the javascript version has this problem). This will be hard to fix because I have to use the c++ version as reference, but I'll try eventually.

====== Others ======
-Text to shape
Explicative by the name. An important thing to keep in mind is that the position of the shape will be centered at 0,0 with \\an7.
Having the shape centered makes it easier to add any rotation or scale tag.

-Inner Shadow
Creates an inner shadow effect. One of the first thing you learn in Illustrator.
You have to 'expand' the text before using this function because it only works with shapes.

-Move shape
Since other (unanimated's) automations removes the decimals, I've added this to the script.
Moves the shape by the specified amount.

-Center Shape
Move the shape so it will have its center to 0,0.

====== Gradient ======
This will allow you to create a gradient in a similar way you'd do in Illustrator.
In order to use this you need to have at least 2 lines (or more depending on how many colors you need) and a clip in the first line of 2 points that will be used as the gradient start and ending point and the direction.
Then you select all the lines you created, open the script and set the step size.
There should also be an option to let the user chose the overlap size, but from the test I've done the best results are obtainable by using the step size as overlap size as well, so I decided to remove it.

====== TO-DO ======
1. A function that 'expands' fax(done), fay(done), frz, frx, fry, fscx(done), fscy(done).
Beside frx and fry I have all this done already. I'm trying to understand how libass does that, but again I'm very bad at understand c and also very bad at math.
2. Simply polygon by recreating bezier curve.
The automation don't work with bezier, so all the path are flattened before being passed to the automation.
By my understanding this only affect the filesize and not the renderer (at least libass), so it's fine to not have this for now. I'm not really sure about this, I might be wrong. 
3. Shape generator.
Just like the most used font 'split spludge', 'grain', etc...
4. Improve the 'Inner Shadow' function.
It has a problem that i don't know how to explain. It's easy to fix anyway."


Yutils = include("Yutils.lua")

ClipperLib = {
	use_lines: true,
	use_xyz: false,

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

-- Temporary. yea i know this is totally useless etc shhh
ClipperLib.Cast_Int64 = (a) ->
	tr = nil
	if a < 0
		tr = a
	else
		tr = a
	return tr

ClipperLib.Cast_Int32 = (a) ->
	return BitNOT(a)

ClipperLib.ClipperBase.OldSlopesEqual3 = (e1, e2, UseFullRange) ->
	if (UseFullRange)
		return Int128.op_Equality(Int128.Int128Mul(e1.Delta.Y, e2.Delta.X), Int128.Int128Mul(e1.Delta.X, e2.Delta.Y))
	else
		return ClipperLib.Cast_Int64((e1.Delta.Y) * (e2.Delta.X)) == ClipperLib.Cast_Int64((e1.Delta.X) * (e2.Delta.Y))

ClipperLib.ClipperBase.OldSlopesEqual4 = (pt1, pt2, pt3, UseFullRange) ->
	if UseFullRange
		return Int128.op_Equality(Int128.Int128Mul(pt1.Y - pt2.Y, pt2.X - pt3.X), Int128.Int128Mul(pt1.X - pt2.X, pt2.Y - pt3.Y))
	else
		return ClipperLib.Cast_Int64((pt1.Y - pt2.Y) * (pt2.X - pt3.X)) - ClipperLib.Cast_Int64((pt1.X - pt2.X) * (pt2.Y - pt3.Y)) == 0

ClipperLib.ClipperBase.OldSlopesEqual5 = (pt1, pt2, pt3, pt4, UseFullRange) ->
	if (UseFullRange)
		return Int128.op_Equality(Int128.Int128Mul(pt1.Y - pt2.Y, pt3.X - pt4.X), Int128.Int128Mul(pt1.X - pt2.X, pt3.Y - pt4.Y))
	else
		return ClipperLib.Cast_Int64((pt1.Y - pt2.Y) * (pt3.X - pt4.X)) - ClipperLib.Cast_Int64((pt1.X - pt2.X) * (pt3.Y - pt4.Y)) == 0

class DoublePoint
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

	class_name: "DoublePoint"

class DoublePoint0
	new: =>
		@X = 0
		@Y = 0

class DoublePoint1
	new: (dp) =>
		@X = dp.X
		@Y = dp.Y

class DoublePoint2
	new: (x, y) =>
		@X = x
		@Y = y

--

BitAND2 = (a, b) ->
	result = 0
	bitval = 1
	while a > 0 and b > 0
		if a % 2 == 1 and b % 2 == 1
			result = result + bitval
		bitval = bitval * 2
		a = math.floor(a/2)
		b = math.floor(b/2)
	return result


BitAND = (a, b) ->
	p, c = 1, 0
	while a>0 and b>0
		ra, rb = a%2, b%2
		if ra+rb>1 then c = c+p
		a, b, p = (a-ra)/2, (b-rb)/2, p*2

	return c

BitNOT = (n) ->
	p, c = 1, 0
	while n>0
		r = n%2
		if r<1 then c=c+p
		n, p = (n-r) / 2, p*2

	return c

BitOR = (a, b) ->
	p, c = 1, 0
	while a+b>0
		ra, rb = a%2, b%2
		if ra+rb>0 then c = c + p
		a, b, p = (a-ra)/2, (b-rb)/2, p*2

	return c

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

ClipperLib.Error = (message) ->
	aegisub.log(message)
	aegisub.cancel!

class Path
	new: =>
		self = {}

class Paths
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

class PolyTree extends PolyNode
	class_name:"PolyTree"

	new: =>
		@m_AllPolys = {}

	Clear: =>
		for i = 1, #@m_AllPolys 
			@m_AllPolys[i] = nil
		@m_AllPolys = nil
		@m_Childs = nil

	GetFirst: =>
		if #@m_Childs > 0
			return @m_Childs[1]
		else
			return nil

	Total: =>
		result = #@m_AllPolys
		--with negative offsets, ignore the hidden outer polygon ...
		if (result > 0 and @m_Childs[1] != @m_AllPolys[1])
			result -= 1
		return result

class Point
	new: (...) =>
		a = {...}
		alen = #a

		@X = 0
		@Y = 0
		if ClipperLib.use_xyz
			@Z = 0

			if alen == 3
				@X = a[1]
				@Y = a[2]
				@Z = a[3]
			elseif alen == 2
				@X = a[1]
				@Y = a[2]
				@Z = 0
			elseif alen == 1
				if a[1].class_name == "DoublePoint"
					dp = a[1]
					@X = dp.X
					@Y = dp.Y
					@Z = 0

				else
					pt = a[1]
					pt.Z = 0 if pt.Z == nil
					@X = pt.X
					@Y = pt.Y
					@Z = pt.Z

			else
				@X = 0
				@Y = 0
				@Z = 0

		else -- if not ClipperLib.use_xyz
			if alen == 2
				@X = a[1]
				@Y = a[2]

			elseif alen == 1
				if a[1].class_name == Point
					dp = a[1]
					@X = dp.X
					@Y = dp.Y

				else
					pt = a[1]
					@X = pt.X
					@Y = pt.Y

			else
				@X = 0
				@Y = 0

	class_name: "Point"

ClipperLib.Point.op_Equality = (a, b) ->
	return a.X == b.X and a.Y == b.Y

ClipperLib.Point.op_Inequality = (a, b) ->
	return a.X != b.X or a.Y != b.Y

class Point0
	new: =>
		@X = 0
		@Y = 0
		if ClipperLib.use_xyz
			@Z = 0

class Point1
	new: (pt) =>
		@X = pt.X
		@Y = pt.Y
		if ClipperLib.use_xyz
			@Z = 0 if pt.Z == nil
		else
			@Z = pt.Z

class Point1dp
	new: (dp) =>
		@X = dp.X
		@Y = dp.Y
		if ClipperLib.use_xyz
			@Z = 0

class Point2
	new: (x, y, z) =>
		@X = x
		@Y = y
		if ClipperLib.use_xyz
			if (z == nil)
				@Z = 0
			else
				@Z = z

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

class Rect0
	new: =>
		@left = 0
		@top = 0
		@right = 0
		@bottom = 0

class Rect1
	new: (ir) =>
		@left = ir.left
		@top = ir.top
		@right = ir.right
		@bottom = ir.bottom

class Rect4
	new: (l, t, r, b) =>
		@left = l
		@top = t
		@right = r
		@bottom = b

class TEdge
	new: =>
		@Bot = Point0!
		@Curr = Point0! --current (updated for every new scanbeam)
		@Top = Point0!
		@Delta = Point0!
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
		@Pt = Point0!

ClipperLib.MyIntersectNodeSort.Compare = (node1, node2) ->
	i = node2.Pt.Y - node1.Pt.Y
	if i > 0
		return 1
	elseif i < 0
		return -1
	else
		return 0

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
		@Pt = Point0!
		@Next = nil
		@Prev = nil

class Join
	new: =>
		@OutPt1 = nil
		@OutPt2 = nil
		@OffPt = Point0!

ClipperLib.ClipperBase.near_zero = (val) ->
	return (val > -ClipperLib.ClipperBase.tolerance) and (val < ClipperLib.ClipperBase.tolerance)

ClipperLib.ClipperBase.IsHorizontal = (e) ->
	return e.Delta.Y == 0

ClipperLib.ClipperBase.SlopesEqual = (...) ->
	a = {...}
	alen = #a
	local e1, e2, pt1, pt2, pt3, pt4
	if (alen == 2) -- function (e1, e2)
		e1 = a[1]
		e2 = a[2]
		return e1.Delta.Y * e2.Delta.X == e1.Delta.X * e2.Delta.Y

	else if (alen == 3) -- function (pt1, pt2, pt3)
		pt1 = a[1]
		pt2 = a[2]
		pt3 = a[3]
		return (pt1.Y - pt2.Y) * (pt2.X - pt3.X) - (pt1.X - pt2.X) * (pt2.Y - pt3.Y) == 0

	else -- function (pt1, pt2, pt3, pt4)
		pt1 = a[1]
		pt2 = a[2]
		pt3 = a[3]
		pt4 = a[4]
		return (pt1.Y - pt2.Y) * (pt3.X - pt4.X) - (pt1.X - pt2.X) * (pt3.Y - pt4.Y) == 0

ClipperLib.ClipperBase.SlopesEqual3 = (e1, e2) ->
	return e1.Delta.Y * e2.Delta.X == e1.Delta.X * e2.Delta.Y

ClipperLib.ClipperBase.SlopesEqual4 = (pt1, pt2, pt3) ->
	return (pt1.Y - pt2.Y) * (pt2.X - pt3.X) - (pt1.X - pt2.X) * (pt2.Y - pt3.Y) == 0

ClipperLib.ClipperBase.SlopesEqual5 = (pt1, pt2, pt3, pt4) ->
	return (pt1.Y - pt2.Y) * (pt3.X - pt4.X) - (pt1.X - pt2.X) * (pt3.Y - pt4.Y) == 0

class ClipperBase
	--questi qua non vanno sotto new?
	m_MinimaList: nil
	m_CurrentLM: nil
	m_edges: {}
	m_HasOpenPaths: false
	PreserveCollinear: false
	m_Scanbeam: nil
	m_PolyOuts: nil
	m_ActiveEdges: nil

	--Temporary
	m_UseFullRange: false

	PointIsVertex: (pt, pp) =>
		pp2 = pp
		while true do
			if (ClipperLib.Point.op_Equality(pp2.Pt, pt))
				return true
			pp2 = pp2.Next

			if pp2 == pp
				break

		return false

	--Temporary
	PointOnLineSegment: (pt, linePt1, linePt2, UseFullRange) =>
		if UseFullRange
			return ((pt.X == linePt1.X) and (pt.Y == linePt1.Y)) or ((pt.X == linePt2.X) and (pt.Y == linePt2.Y)) or (((pt.X > linePt1.X) == (pt.X < linePt2.X)) and ((pt.Y > linePt1.Y) == (pt.Y < linePt2.Y)) and (Int128.op_Equality(Int128.Int128Mul((pt.X - linePt1.X), (linePt2.Y - linePt1.Y)), Int128.Int128Mul((linePt2.X - linePt1.X), (pt.Y - linePt1.Y)))))
		else
			return ((pt.X == linePt1.X) and (pt.Y == linePt1.Y)) or ((pt.X == linePt2.X) and (pt.Y == linePt2.Y)) or (((pt.X > linePt1.X) == (pt.X < linePt2.X)) and ((pt.Y > linePt1.Y) == (pt.Y < linePt2.Y)) and ((pt.X - linePt1.X) * (linePt2.Y - linePt1.Y) == (linePt2.X - linePt1.X) * (pt.Y - linePt1.Y)))

	[[PointOnLineSegment: (pt, linePt1, linePt2) =>
		return ((pt.X == linePt1.X) and (pt.Y == linePt1.Y)) or ((pt.X == linePt2.X) and (pt.Y == linePt2.Y)) or (((pt.X > linePt1.X) == (pt.X < linePt2.X)) and ((pt.Y > linePt1.Y) == (pt.Y < linePt2.Y)) and ((pt.X - linePt1.X) * (linePt2.Y - linePt1.Y) == (linePt2.X - linePt1.X) * (pt.Y - linePt1.Y)))]]

	--Temporary
	PointOnPolygon: (pt, pp, UseFullRange) =>
		pp2 = pp
		while true do
			if @PointOnLineSegment(pt, pp2.Pt, pp2.Next.Pt, UseFullRange)
				return true
			pp2 = pp2.Next
			if pp2 == pp
				break
		return false

	[[PointOnPolygon: (pt, pp) =>
		pp2 = pp
		while true do
			if @PointOnLineSegment(pt, pp2.Pt, pp2.Next.Pt)
				return true
			pp2 = pp2.Next
			if pp2 == pp
				break

		return false]]

	--Temporary
	Clear: =>
		@DisposeLocalMinimaList!
		for i = 1, #@m_edges
			for j = 1, #@m_edges[i]
				@m_edges[i][j] = nil
			@m_edges[i] = ClipperLib.Clear!
		@m_edges = ClipperLib.Clear!
		@m_UseFullRange = false
		@m_HasOpenPaths = false

	[[Clear: =>
		@DisposeLocalMinimaList!
		for i = 1, #@m_edges
			for j = 1, #@m_edges[i]
				@m_edges[i][j] = nil
			@m_edges[i] = ClipperLib.Clear!

		@m_edges = ClipperLib.Clear!
		@m_HasOpenPaths = false
		@m_UseFullRange = false]]

	DisposeLocalMinimaList: =>
		while (@m_MinimaList != nil)
			tmpLm = @m_MinimaList.Next
			@m_MinimaList = nil
			@m_MinimaList = tmpLm

		@m_CurrentLM = nil

	--Temporary
	RangeTest: (Pt, useFullRange) =>
		if useFullRange.Value
			if (Pt.X > ClipperLib.ClipperBase.hiRange or Pt.Y > ClipperLib.ClipperBase.hiRange or -Pt.X > ClipperLib.ClipperBase.hiRange or -Pt.Y > ClipperLib.ClipperBase.hiRange)
				ClipperLib.Error("Coordinate outside allowed range in RangeTest().")
		elseif (Pt.X > ClipperLib.ClipperBase.loRange or Pt.Y > ClipperLib.ClipperBase.loRange or -Pt.X > ClipperLib.ClipperBase.loRange or -Pt.Y > ClipperLib.ClipperBase.loRange)
			useFullRange.Value = true
			@RangeTest(Pt, useFullRange)

	[[RangeTest: (pt) =>
		if (pt.X > ClipperLib.ClipperBase.maxValue or pt.X < -ClipperLib.ClipperBase.maxValue or pt.Y > ClipperLib.ClipperBase.maxValue or pt.Y < -ClipperLib.ClipperBase.maxValue or (pt.X > 0 and pt.X < ClipperLib.ClipperBase.minValue) or (pt.Y > 0 and pt.Y < ClipperLib.ClipperBase.minValue) or (pt.X < 0 and pt.X > -ClipperLib.ClipperBase.minValue) or (pt.Y < 0 and pt.Y > -ClipperLib.ClipperBase.minValue))
			ClipperLib.Error("Coordinate outside allowed range in RangeTest().")]]

	InitEdge: (e, eNext, ePrev, pt) =>
		e.Next = eNext
		e.Prev = ePrev
		e.Curr.X = pt.X
		e.Curr.Y = pt.Y
		if ClipperLib.use_xyz
			e.Curr.Z = pt.Z
		e.OutIdx = -1

	InitEdge2: (e, polyType) =>
		if (e.Curr.Y >= e.Next.Curr.Y)
			e.Bot.X = e.Curr.X
			e.Bot.Y = e.Curr.Y
			if (ClipperLib.use_xyz)
				e.Bot.Z = e.Curr.Z
			e.Top.X = e.Next.Curr.X
			e.Top.Y = e.Next.Curr.Y
			if (ClipperLib.use_xyz)
				e.Top.Z = e.Next.Curr.Z
		else
			e.Top.X = e.Curr.X
			e.Top.Y = e.Curr.Y
			if (ClipperLib.use_xyz)
				e.Top.Z = e.Curr.Z
			e.Bot.X = e.Next.Curr.X
			e.Bot.Y = e.Next.Curr.Y
			if (ClipperLib.use_xyz)
				e.Bot.Z = e.Next.Curr.Z

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
		if ClipperLib.use_xyz
			edges[2].Curr.Z = pg[2].Z

		--non servono ma corretti
		--@RangeTest(pg[1])
		--@RangeTest(pg[highI])
		
		@InitEdge(edges[1], edges[2], edges[highI], pg[1])
		@InitEdge(edges[highI], edges[1], edges[highI - 1], pg[highI])

		for i = highI - 1, 2, -1
			--non serve ma corretto
			--@RangeTest(pg[i])
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
			
			--Temporary
			elseif (Closed and ClipperLib.ClipperBase.OldSlopesEqual4(E.Prev.Curr, E.Curr, E.Next.Curr, @m_UseFullRange) and (not @PreserveCollinear or @Pt2IsBetweenPt1AndPt3(E.Prev.Curr, E.Curr, E.Next.Curr)))
			--elseif (Closed and ClipperLib.ClipperBase.SlopesEqual4(E.Prev.Curr, E.Curr, E.Next.Curr) and (not @PreserveCollinear or @Pt2IsBetweenPt1AndPt3(E.Prev.Curr, E.Curr, E.Next.Curr)))
			
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
		if (ClipperLib.use_xyz)
			tmp = e.Top.Z
			e.Top.Z = e.Bot.Z
			e.Bot.Z = tmp

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
				if (ClipperLib.use_xyz)
					e.Curr.Z = e.Bot.Z
				e.OutIdx = ClipperLib.ClipperBase.Unassigned

			e = lm.RightBound
			if (e != nil)
				e.Curr.X = e.Bot.X
				e.Curr.Y = e.Bot.Y
				if (ClipperLib.use_xyz)
					e.Curr.Z = e.Bot.Z
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

ClipperLib.Clipper.ReversePaths = (polys) ->
	for i = 1, #polys
		reversed = {}
		for j = #polys[i], 1, -1
			table.insert(reversed, polys[i][j])
		polys[i] = reversed

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

ClipperLib.Clipper.PointInPolygon = (pt, path) ->
	--returns 0 if false, +1 if true, -1 if pt ON polygon boundary
	--See "The Point in Polygon Problem for Arbitrary Polygons" by Hormann & Agathos
	--http:--citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.88.5498&rep=rep1&type=pdf
	result = 0
	cnt = #path
	if (cnt < 3)
		return 0
	ip = path[1]
	for i = 1, cnt
		ipNext = nil
		if i == cnt
			ipNext = path[1]
		else
			ipNext = path[i]

		if (ipNext.Y == pt.Y)
			if ((ipNext.X == pt.X) or (ip.Y == pt.Y and ((ipNext.X > pt.X) == (ip.X < pt.X))))
				return -1
		if ((ip.Y < pt.Y) != (ipNext.Y < pt.Y))
			if (ip.X >= pt.X)
				if (ipNext.X > pt.X)
					result = 1 - result
				else
					d = (ip.X - pt.X) * (ipNext.Y - pt.Y) - (ipNext.X - pt.X) * (ip.Y - pt.Y)
					if (d == 0)
						return -1
					elseif ((d > 0) == (ipNext.Y > ip.Y))
						result = 1 - result
			else
				if (ipNext.X > pt.X)
					d = (ip.X - pt.X) * (ipNext.Y - pt.Y) - (ipNext.X - pt.X) * (ip.Y - pt.Y)
					if (d == 0)
						return -1
					elseif ((d > 0) == (ipNext.Y > ip.Y))
						result = 1 - result

		ip = ipNext

	return result

ClipperLib.Clipper.ParseFirstLeft = (FirstLeft) ->
	while (FirstLeft != nil and FirstLeft.Pts == nil)
		FirstLeft = FirstLeft.FirstLeft
	return FirstLeft

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

ClipperLib.Clipper.SimplifyPolygon = (poly, fillType) ->
	result = {}
	c = Clipper!
	c.StrictlySimple = true
	c\AddPath(poly, ClipperLib.PolyType.ptSubject, true)
	succeeded, result = c\Execute(ClipperLib.ClipType.ctUnion, result, fillType, fillType)
	return result

ClipperLib.Clipper.SimplifyPolygons = (polys, fillType) ->
	if (fillType == nil)
		fillType = ClipperLib.PolyFillType.pftEvenOdd
	result = {}
	c = Clipper!
	c.StrictlySimple = true
	c\AddPaths(polys, ClipperLib.PolyType.ptSubject, true)
	succeeded, result = c\Execute(ClipperLib.ClipType.ctUnion, result, fillType, fillType)
	return result

ClipperLib.Clipper.DistanceSqrd = (pt1, pt2) ->
	dx = (pt1.X - pt2.X)
	dy = (pt1.Y - pt2.Y)
	return (dx * dx + dy * dy)

ClipperLib.Clipper.DistanceFromLineSqrd = (pt, ln1, ln2) ->
	--The equation of a line in general form (Ax + By + C = 0)
	--given 2 points (x¹,y¹) & (x²,y²) is ...
	--(y¹ - y²)x + (x² - x¹)y + (y² - y¹)x¹ - (x² - x¹)y¹ = 0
	--A = (y¹ - y²); B = (x² - x¹); C = (y² - y¹)x¹ - (x² - x¹)y¹
	--perpendicular distance of point (x³,y³) = (Ax³ + By³ + C)/Sqrt(A² + B²)
	--see http://en.wikipedia.org/wiki/Perpendicular_distance
	A = ln1.Y - ln2.Y
	B = ln2.X - ln1.X
	C = A * ln1.X + B * ln1.Y
	C = A * pt.X + B * pt.Y - C
	return (C * C) / (A * A + B * B)

ClipperLib.Clipper.SlopesNearCollinear = (pt1, pt2, pt3, distSqrd) ->
	--this function is more accurate when the point that's GEOMETRICALLY
	--between the other 2 points is the one that's tested for distance.
	--nb: with 'spikes', either pt1 or pt3 is geometrically between the other pts
	if (math.abs(pt1.X - pt2.X) > math.abs(pt1.Y - pt2.Y))
		if ((pt1.X > pt2.X) == (pt1.X < pt3.X))
			return ClipperLib.Clipper.DistanceFromLineSqrd(pt1, pt2, pt3) < distSqrd
		elseif ((pt2.X > pt1.X) == (pt2.X < pt3.X))
			return ClipperLib.Clipper.DistanceFromLineSqrd(pt2, pt1, pt3) < distSqrd
		else
			return ClipperLib.Clipper.DistanceFromLineSqrd(pt3, pt1, pt2) < distSqrd

	else
		if ((pt1.Y > pt2.Y) == (pt1.Y < pt3.Y))
			return ClipperLib.Clipper.DistanceFromLineSqrd(pt1, pt2, pt3) < distSqrd
		elseif ((pt2.Y > pt1.Y) == (pt2.Y < pt3.Y))
			return ClipperLib.Clipper.DistanceFromLineSqrd(pt2, pt1, pt3) < distSqrd
		else
			return ClipperLib.Clipper.DistanceFromLineSqrd(pt3, pt1, pt2) < distSqrd

ClipperLib.Clipper.PointsAreClose = (pt1, pt2, distSqrd) ->
	dx = pt1.X - pt2.X
	dy = pt1.Y - pt2.Y
	return ((dx * dx) + (dy * dy) <= distSqrd)

ClipperLib.Clipper.ExcludeOp = (op) ->
	result = op.Prev
	result.Next = op.Next
	op.Next.Prev = result
	result.Idx = 0
	return result

ClipperLib.Clipper.CleanPolygon = (path, distance) ->
	if (distance == nil)
		distance = 1.415
	--distance = proximity in units/pixels below which vertices will be stripped.
	--Default ~= sqrt(2) so when adjacent vertices or semi-adjacent vertices have
	--both x & y coords within 1 unit, then the second vertex will be stripped.
	cnt = #path
	if (cnt == 0)
		return {}
	outPts = {cnt}
	for i = 1, cnt
		outPts[i] = OutPt!
	for i = 1, cnt
		outPts[i].Pt = path[i]
		outPts[i].Next = outPts[(i + 1) % cnt]
		outPts[i].Next.Prev = outPts[i]
		outPts[i].Idx = 0

	distSqrd = distance * distance
	op = outPts[0]
	while (op.Idx == 0 and op.Next != op.Prev)
		if (ClipperLib.Clipper.PointsAreClose(op.Pt, op.Prev.Pt, distSqrd))
			op = ClipperLib.Clipper.ExcludeOp(op)
			cnt -= 1

		elseif (ClipperLib.Clipper.PointsAreClose(op.Prev.Pt, op.Next.Pt, distSqrd))
			ClipperLib.Clipper.ExcludeOp(op.Next)
			op = ClipperLib.Clipper.ExcludeOp(op)
			cnt -= 2

		elseif (ClipperLib.Clipper.SlopesNearCollinear(op.Prev.Pt, op.Pt, op.Next.Pt, distSqrd))
			op = ClipperLib.Clipper.ExcludeOp(op)
			cnt -= 1

		else
			op.Idx = 1
			op = op.Next

	if (cnt < 3)
		cnt = 0
	result = {cnt}
	for i = 1, cnt
		result[i] = Point1(op.Pt)
		op = op.Next

	outPts = nil
	return result

ClipperLib.Clipper.CleanPolygons = (polys, distance) ->
	result = {#polys}
	for i = 1, #polys
		result[i] = ClipperLib.Clipper.CleanPolygon(polys[i], distance)
	return result

[[
	ClipperLib.Clipper.Minkowski = function (pattern, path, IsSum, IsClosed)
	{
		var delta = (IsClosed ? 1 : 0);
		var polyCnt = pattern.length;
		var pathCnt = path.length;
		var result = new Array();
		if (IsSum)
			for (var i = 0; i < pathCnt; i++)
			{
				var p = new Array(polyCnt);
				for (var j = 0, jlen = pattern.length, ip = pattern[j]; j < jlen; j++, ip = pattern[j])
					p[j] = new ClipperLib.FPoint2(path[i].X + ip.X, path[i].Y + ip.Y);
				result.push(p);
			}
		else
			for (var i = 0; i < pathCnt; i++)
			{
				var p = new Array(polyCnt);
				for (var j = 0, jlen = pattern.length, ip = pattern[j]; j < jlen; j++, ip = pattern[j])
					p[j] = new ClipperLib.FPoint2(path[i].X - ip.X, path[i].Y - ip.Y);
				result.push(p);
			}
		var quads = new Array();
		for (var i = 0; i < pathCnt - 1 + delta; i++)
			for (var j = 0; j < polyCnt; j++)
			{
				var quad = new Array();
				quad.push(result[i % pathCnt][j % polyCnt]);
				quad.push(result[(i + 1) % pathCnt][j % polyCnt]);
				quad.push(result[(i + 1) % pathCnt][(j + 1) % polyCnt]);
				quad.push(result[i % pathCnt][(j + 1) % polyCnt]);
				if (!ClipperLib.Clipper.Orientation(quad))
					quad.reverse();
				quads.push(quad);
			}
		return quads;
	};

	ClipperLib.Clipper.MinkowskiSum = function (pattern, path_or_paths, pathIsClosed)
	{
		if (!(path_or_paths[0] instanceof Array))
		{
			var path = path_or_paths;
			var paths = ClipperLib.Clipper.Minkowski(pattern, path, true, pathIsClosed);
			var c = new ClipperLib.Clipper();
			c.AddPaths(paths, ClipperLib.PolyType.ptSubject, true);
			c.Execute(ClipperLib.ClipType.ctUnion, paths, ClipperLib.PolyFillType.pftNonZero, ClipperLib.PolyFillType.pftNonZero);
			return paths;
		}
		else
		{
			var paths = path_or_paths;
			var solution = new ClipperLib.Paths();
			var c = new ClipperLib.Clipper();
			for (var i = 0; i < paths.length; ++i)
			{
				var tmp = ClipperLib.Clipper.Minkowski(pattern, paths[i], true, pathIsClosed);
				c.AddPaths(tmp, ClipperLib.PolyType.ptSubject, true);
				if (pathIsClosed)
				{
					var path = ClipperLib.Clipper.TranslatePath(paths[i], pattern[0]);
					c.AddPath(path, ClipperLib.PolyType.ptClip, true);
				}
			}
			c.Execute(ClipperLib.ClipType.ctUnion, solution,
				ClipperLib.PolyFillType.pftNonZero, ClipperLib.PolyFillType.pftNonZero);
			return solution;
		}
	}

	ClipperLib.Clipper.TranslatePath = function (path, delta)
	{
		var outPath = new ClipperLib.Path();
		for (var i = 0; i < path.length; i++)
			outPath.push(new ClipperLib.FPoint2(path[i].X + delta.X, path[i].Y + delta.Y));
		return outPath;
	}

	ClipperLib.Clipper.MinkowskiDiff = function (poly1, poly2)
	{
		var paths = ClipperLib.Clipper.Minkowski(poly1, poly2, false, true);
		var c = new ClipperLib.Clipper();
		c.AddPaths(paths, ClipperLib.PolyType.ptSubject, true);
		c.Execute(ClipperLib.ClipType.ctUnion, paths, ClipperLib.PolyFillType.pftNonZero, ClipperLib.PolyFillType.pftNonZero);
		return paths;
	}

	ClipperLib.Clipper.PolyTreeToPaths = function (polytree)
	{
		var result = new Array();
		//result.set_Capacity(polytree.get_Total());
		ClipperLib.Clipper.AddPolyNodeToPaths(polytree, ClipperLib.Clipper.NodeType.ntAny, result);
		return result;
	};

	ClipperLib.Clipper.AddPolyNodeToPaths = function (polynode, nt, paths)
	{
		var match = true;
		switch (nt)
		{
			case ClipperLib.Clipper.NodeType.ntOpen:
				return;
			case ClipperLib.Clipper.NodeType.ntClosed:
				match = !polynode.IsOpen;
				break;
			default:
				break;
		}
		if (polynode.m_polygon.length > 0 && match)
			paths.push(polynode.m_polygon);
		for (var $i3 = 0, $t3 = polynode.Childs(), $l3 = $t3.length, pn = $t3[$i3]; $i3 < $l3; $i3++, pn = $t3[$i3])
			ClipperLib.Clipper.AddPolyNodeToPaths(pn, nt, paths);
	};

	ClipperLib.Clipper.OpenPathsFromPolyTree = function (polytree)
	{
		var result = new ClipperLib.Paths();
		//result.set_Capacity(polytree.ChildCount());
		for (var i = 0, ilen = polytree.ChildCount(); i < ilen; i++)
			if (polytree.Childs()[i].IsOpen)
				result.push(polytree.Childs()[i].m_polygon);
		return result;
	};

	ClipperLib.Clipper.ClosedPathsFromPolyTree = function (polytree)
	{
		var result = new ClipperLib.Paths();
		//result.set_Capacity(polytree.Total());
		ClipperLib.Clipper.AddPolyNodeToPaths(polytree, ClipperLib.Clipper.NodeType.ntClosed, result);
		return result;
	};
]]

class Clipper extends ClipperBase
	new: (InitOptions) =>
		if InitOptions == nil then InitOptions = 0
		@m_edges = {} --?

		@m_ClipType = ClipperLib.ClipType.ctIntersection
		@m_ClipFillType = ClipperLib.PolyFillType.pftEvenOdd
		@m_SubjFillType = ClipperLib.PolyFillType.pftEvenOdd
		@m_UsingPolyTree = false
		@m_Scanbeam = nil
		@m_Maxima = nil
		@m_ActiveEdges = nil
		@m_SortedEdges = nil
		@m_IntersectList = {}
		@m_IntersectNodeComparer = ClipperLib.MyIntersectNodeSort.Compare
		@m_ExecuteLocked = false
		@m_UsingPolyTree = false
		@m_PolyOuts = {}
		@m_Joins = {}
		@m_GhostJoins = {}
		@ReverseSolution = BitAND2(1, 0) != 0
		--@StrictlySimple = BitAND(2, InitOptions) != 0
		--@PreserveCollinear = BitAND(4, InitOptions) != 0
		if (ClipperLib.use_xyz)
			@ZFillFunction = nil
	
	Clear: =>
		if (#@m_edges == 0)
			return
		@DisposeAllPolyPts!
		--ClipperLib.ClipperBase.prototype.Clear.call(this);dafare

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

	Execute: (...) =>
		a = {...}
		alen = #a
		ispolytree = a[2].class_name == "PolyTree"

		if alen == 4 and not ispolytree -- function (clipType, solution, subjFillType, clipFillType)
			clipType = a[1]
			solution = a[2]
			subjFillType = a[3]
			clipFillType = a[4]
			if @m_ExecuteLocked
				return false
			if @m_HasOpenPaths
				ClipperLib.Error("Error: PolyTree struct is needed for open path clipping.")

			@m_ExecuteLocked = true
			solution = ClipperLib.Clear!
			@m_SubjFillType = subjFillType
			@m_ClipFillType = clipFillType
			@m_ClipType = clipType
			@m_UsingPolyTree = false

			succeeded = @ExecuteInternal!
			if (succeeded)
				solution = @BuildResult!

			@DisposeAllPolyPts!
			@m_ExecuteLocked = false

			return succeeded, solution

		elseif alen == 4 and ispolytree -- function (clipType, polytree, subjFillType, clipFillType)
			clipType = a[1]
			polytree = a[2]
			subjFillType = a[3]
			clipFillType = a[4]
			if @m_ExecuteLocked
				return false
			@m_ExecuteLocked = true
			@m_SubjFillType = subjFillType
			@m_ClipFillType = clipFillType
			@m_ClipType = clipType
			@m_UsingPolyTree = true
		
			succeeded = @ExecuteInternal!
			if (succeeded)
				@BuildResult2(polytree)

			@DisposeAllPolyPts!
			@m_ExecuteLocked = false

			return polytree

		elseif alen == 2 and not ispolytree -- function (clipType, solution)
			clipType = a[1]
			solution = a[2]
			return @Execute(clipType, solution, ClipperLib.PolyFillType.pftEvenOdd, ClipperLib.PolyFillType.pftEvenOdd)

		elseif alen == 2 and ispolytree -- function (clipType, polytree)
			clipType = a[1]
			polytree = a[2]
			return @Execute(clipType, polytree, ClipperLib.PolyFillType.pftEvenOdd, ClipperLib.PolyFillType.pftEvenOdd)

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
		--try
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


		--finally
		@m_Joins = {}
		@m_GhostJoins = {}
		return true --questo true è prima di finally, funziona uguale?

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
		if (ClipperLib.use_xyz)
			j.OffPt.Z = OffPt.Z

		table.insert(@m_Joins, j)

	AddGhostJoin: (Op, OffPt) =>
		j = Join!
		j.OutPt1 = Op
		j.OffPt.X = OffPt.X
		j.OffPt.Y = OffPt.Y
		if (ClipperLib.use_xyz)
			j.OffPt.Z = OffPt.Z
		table.insert(@m_GhostJoins, j)

	SetZ: (pt, e1, e2) =>
		if (@ZFillFunction != nil)
			if (pt.Z != 0 or @ZFillFunction == nil)
				return
			elseif (ClipperLib.Point.op_Equality(pt, e1.Bot))
				pt.Z = e1.Bot.Z
			elseif (ClipperLib.Point.op_Equality(pt, e1.Top))
				pt.Z = e1.Top.Z
			elseif (ClipperLib.Point.op_Equality(pt, e2.Bot))
				pt.Z = e2.Bot.Z
			elseif (ClipperLib.Point.op_Equality(pt, e2.Top))
				pt.Z = e2.Top.Z
			else
				@ZFillFunction(e1.Bot, e1.Top, e2.Bot, e2.Top, pt)

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

			--Temporary
			if (lb.OutIdx >= 0 and lb.PrevInAEL != nil and lb.PrevInAEL.Curr.X == lb.Bot.X and lb.PrevInAEL.OutIdx >= 0 and ClipperLib.ClipperBase.OldSlopesEqual5(lb.PrevInAEL.Curr, lb.PrevInAEL.Top, lb.Curr, lb.Top, @m_UseFullRange) and lb.WindDelta != 0 and lb.PrevInAEL.WindDelta != 0)
			--if (lb.OutIdx >= 0 and lb.PrevInAEL != nil and lb.PrevInAEL.Curr.X == lb.Bot.X and lb.PrevInAEL.OutIdx >= 0 and ClipperLib.ClipperBase.SlopesEqual5(lb.PrevInAEL.Curr, lb.PrevInAEL.Top, lb.Curr, lb.Top) and lb.WindDelta != 0 and lb.PrevInAEL.WindDelta != 0)

				Op2 = @AddOutPt(lb.PrevInAEL, lb.Bot)
				@AddJoin(Op1, Op2, lb.Top)

			if (lb.NextInAEL != rb)

				--Temporary
				if (rb.OutIdx >= 0 and rb.PrevInAEL.OutIdx >= 0 and ClipperLib.ClipperBase.OldSlopesEqual5(rb.PrevInAEL.Curr, rb.PrevInAEL.Top, rb.Curr, rb.Top, @m_UseFullRange) and rb.WindDelta != 0 and rb.PrevInAEL.WindDelta != 0)
				--if (rb.OutIdx >= 0 and rb.PrevInAEL.OutIdx >= 0 and ClipperLib.ClipperBase.SlopesEqual5(rb.PrevInAEL.Curr, rb.PrevInAEL.Top, rb.Curr, rb.Top) and rb.WindDelta != 0 and rb.PrevInAEL.WindDelta != 0)

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

			--Temporary
			if ((xPrev == xE) and (e.WindDelta != 0) and (prevE.WindDelta != 0) and ClipperLib.ClipperBase.OldSlopesEqual5(Point2(xPrev, pt.Y), prevE.Top, Point2(xE, pt.Y), e.Top, @m_UseFullRange))
			--if ((xPrev == xE) and (e.WindDelta != 0) and (prevE.WindDelta != 0) and ClipperLib.ClipperBase.SlopesEqual5(Point(xPrev, pt.Y), prevE.Top, Point(xE, pt.Y), e.Top))

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
			--newOp.Pt = pt
			newOp.Pt.X = pt.X
			newOp.Pt.Y = pt.Y
			if (ClipperLib.use_xyz)
				newOp.Pt.Z = pt.Z
			newOp.Next = newOp
			newOp.Prev = newOp
			if (not outRec.IsOpen)
				@SetHoleState(e, outRec)
			e.OutIdx = outRec.Idx
			--nb: do this after SetZ !
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
			--newOp.Pt = pt
			newOp.Pt.X = pt.X
			newOp.Pt.Y = pt.Y
			if (ClipperLib.use_xyz)
				newOp.Pt.Z = pt.Z
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
		tmp = Point1(pt1.Value)

		pt1.Value.X = pt2.Value.X
		pt1.Value.Y = pt2.Value.Y
		if (ClipperLib.use_xyz)
			pt1.Value.Z = pt2.Value.Z

		pt2.Value.X = tmp.X
		pt2.Value.Y = tmp.Y
		if (ClipperLib.use_xyz)
			pt2.Value.Z = tmp.Z

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

		if (ClipperLib.use_xyz)
			@SetZ(pt, e1, e2)

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
								@AddOutPt(horzEdge, Point2(currMax.X, horzEdge.Bot.Y))
							currMax = currMax.Next

					else
						while (currMax != nil and currMax.X > e.Curr.X)
							if (horzEdge.OutIdx >= 0 and not IsOpen)
								@AddOutPt(horzEdge, Point2(currMax.X, horzEdge.Bot.Y))
							currMax = currMax.Prev

				if ((dir == ClipperLib.Direction.dLeftToRight and e.Curr.X > horzRight) or (dir == ClipperLib.Direction.dRightToLeft and e.Curr.X < horzLeft))
					break

				--Also break if we've got to the end of an intermediate horizontal edge ...
				--nb: Smaller Dx's are to the right of larger Dx's ABOVE the horizontal.
				if (e.Curr.X == horzEdge.Top.X and horzEdge.NextInLML != nil and e.Dx < horzEdge.NextInLML.Dx)
					break

				if (horzEdge.OutIdx >= 0 and not IsOpen) --note: may be done multiple times
					if (ClipperLib.use_xyz)
						if (dir == ClipperLib.Direction.dLeftToRight)
							@SetZ(e.Curr, horzEdge, e)
						else
							@SetZ(e.Curr, e, horzEdge)

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

					Pt = Point2(e.Curr.X, horzEdge.Curr.Y)
					@IntersectEdges(horzEdge, e, Pt)

				else
					Pt = Point2(e.Curr.X, horzEdge.Curr.Y)
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

				--Temporary
				if (ePrev != nil and ePrev.Curr.X == horzEdge.Bot.X and ePrev.Curr.Y == horzEdge.Bot.Y and ePrev.WindDelta == 0 and (ePrev.OutIdx >= 0 and ePrev.Curr.Y > ePrev.Top.Y and ClipperLib.ClipperBase.OldSlopesEqual3(horzEdge, ePrev, @m_UseFullRange)))
				--if (ePrev != nil and ePrev.Curr.X == horzEdge.Bot.X and ePrev.Curr.Y == horzEdge.Bot.Y and ePrev.WindDelta == 0 and (ePrev.OutIdx >= 0 and ePrev.Curr.Y > ePrev.Top.Y and ClipperLib.ClipperBase.SlopesEqual3(horzEdge, ePrev)))

					op2 = @AddOutPt(ePrev, horzEdge.Bot)
					@AddJoin(op1, op2, horzEdge.Top)

				--Temporary
				elseif (eNext != nil and eNext.Curr.X == horzEdge.Bot.X and eNext.Curr.Y == horzEdge.Bot.Y and eNext.WindDelta != 0 and eNext.OutIdx >= 0 and eNext.Curr.Y > eNext.Top.Y and ClipperLib.ClipperBase.OldSlopesEqual3(horzEdge, eNext, @m_UseFullRange))
				--elseif (eNext != nil and eNext.Curr.X == horzEdge.Bot.X and eNext.Curr.Y == horzEdge.Bot.Y and eNext.WindDelta != 0 and eNext.OutIdx >= 0 and eNext.Curr.Y > eNext.Top.Y and ClipperLib.ClipperBase.SlopesEqual3(horzEdge, eNext))

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
				pt = Point0!
				if (e.Curr.X > eNext.Curr.X)
					@IntersectPoint(e, eNext, pt)
					if (pt.Y < topY)
						pt = Point2(ClipperLib.Clipper.TopX(e, topY), topY)

					newNode = IntersectNode!
					newNode.Edge1 = e
					newNode.Edge2 = eNext

					newNode.Pt.X = pt.X
					newNode.Pt.Y = pt.Y
					if (ClipperLib.use_xyz)
						newNode.Pt.Z = pt.Z
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
		--DA FARE @m_IntersectList.sort(@m_IntersectNodeComparer)
		@CopyAELToSEL!
		cnt = #@m_IntersectList
		for i = 1, cnt
			if (not @EdgesAdjacent(@m_IntersectList[i]))
				j = i + 1
				while (j < cnt and not @EdgesAdjacent(@m_IntersectList[j])) -- j <= cnt???
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

				if (ClipperLib.use_xyz)
					if (e.Top.Y == topY)
						e.Curr.Z = e.Top.Z
					elseif (e.Bot.Y == topY)
						e.Curr.Z = e.Bot.Z
					else
						e.Curr.Z = 0

				--When StrictlySimple and 'e' is being touched by another edge, then
				--make sure both edges have a vertex here ...        
				if (@StrictlySimple)
					ePrev = e.PrevInAEL
					if ((e.OutIdx >= 0) and (e.WindDelta != 0) and ePrev != nil and (ePrev.OutIdx >= 0) and (ePrev.Curr.X == e.Curr.X) and (ePrev.WindDelta != 0))
						ip = Point1(e.Curr)

						if (ClipperLib.use_xyz)
							@SetZ(ip, ePrev, e)

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

				--Temporary
				if (ePrev != nil and ePrev.Curr.X == e.Bot.X and ePrev.Curr.Y == e.Bot.Y and op != nil and ePrev.OutIdx >= 0 and ePrev.Curr.Y == ePrev.Top.Y and ClipperLib.ClipperBase.OldSlopesEqual5(e.Curr, e.Top, ePrev.Curr, ePrev.Top, @m_UseFullRange) and (e.WindDelta != 0) and (ePrev.WindDelta != 0))
				--if (ePrev != nil and ePrev.Curr.X == e.Bot.X and ePrev.Curr.Y == e.Bot.Y and op != nil and ePrev.OutIdx >= 0 and ePrev.Curr.Y == ePrev.Top.Y and ClipperLib.ClipperBase.SlopesEqual5(e.Curr, e.Top, ePrev.Curr, ePrev.Top) and (e.WindDelta != 0) and (ePrev.WindDelta != 0))

					op2 = @AddOutPt(ePrev2, e.Bot)
					@AddJoin(op, op2, e.Top)

				--Temporary
				elseif (eNext != nil and eNext.Curr.X == e.Bot.X and eNext.Curr.Y == e.Bot.Y and op != nil and eNext.OutIdx >= 0 and eNext.Curr.Y == eNext.Top.Y and ClipperLib.ClipperBase.OldSlopesEqual5(e.Curr, e.Top, eNext.Curr, eNext.Top, @m_UseFullRange) and (e.WindDelta != 0) and (eNext.WindDelta != 0))
				--elseif (eNext != nil and eNext.Curr.X == e.Bot.X and eNext.Curr.Y == e.Bot.Y and op != nil and eNext.OutIdx >= 0 and eNext.Curr.Y == eNext.Top.Y and ClipperLib.ClipperBase.SlopesEqual5(e.Curr, e.Top, eNext.Curr, eNext.Top) and (e.WindDelta != 0) and (eNext.WindDelta != 0))

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

		return polyg

	BuildResult2: (polytree) =>
		--add each output polygon/contour to polytree ...
		for i = 1, #@m_PolyOuts
			outRec = @m_PolyOuts[i]
			cnt = @PointCount(outRec.Pts)
			if ((outRec.IsOpen and cnt < 2) or (not outRec.IsOpen and cnt < 3))
				continue
			@FixHoleLinkage(outRec)
			pn = PolyNode!
			table.insert(polytree.m_AllPolys, pn)
			outRec.PolyNode = pn
			pn.m_polygon.length = cnt
			op = outRec.Pts.Prev
			for j = 1, cnt
				pn.m_polygon[j] = op.Pt
				op = op.Prev

		--fixup PolyNode links etc ...
		--polytree.m_Childs.set_Capacity(this.m_PolyOuts.length);
		for i = 1, #@m_PolyOuts
			outRec = @m_PolyOuts[i]
			if (outRec.PolyNode == nil)
				continue
			elseif (outRec.IsOpen)
				outRec.PolyNode.IsOpen = true
				polytree\AddChild(outRec.PolyNode)
			elseif (outRec.FirstLeft != nil and outRec.FirstLeft.PolyNode != nil)
				outRec.FirstLeft.PolyNode\AddChild(outRec.PolyNode)
			else
				polytree\AddChild(outRec.PolyNode)

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

			--Temporary
			if ((ClipperLib.Point.op_Equality(pp.Pt, pp.Next.Pt)) or (ClipperLib.Point.op_Equality(pp.Pt, pp.Prev.Pt)) or (ClipperLib.ClipperBase.OldSlopesEqual4(pp.Prev.Pt, pp.Pt, pp.Next.Pt, @m_UseFullRange) and (not preserveCol or not @Pt2IsBetweenPt1AndPt3(pp.Prev.Pt, pp.Pt, pp.Next.Pt))))
			--if ((ClipperLib.Point.op_Equality(pp.Pt, pp.Next.Pt)) or (ClipperLib.Point.op_Equality(pp.Pt, pp.Prev.Pt)) or (ClipperLib.ClipperBase.SlopesEqual4(pp.Prev.Pt, pp.Pt, pp.Next.Pt) and (not preserveCol or not @Pt2IsBetweenPt1AndPt3(pp.Prev.Pt, pp.Pt, pp.Next.Pt))))

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
		--result.Pt = outPt.Pt;
		result.Pt.X = outPt.Pt.X
		result.Pt.Y = outPt.Pt.Y
		if (ClipperLib.use_xyz)
			result.Pt.Z = outPt.Pt.Z
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
				if (ClipperLib.use_xyz)
					op1.Pt.Z = Pt.Z
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
				if (ClipperLib.use_xyz)
					op1.Pt.Z = Pt.Z
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
				if (ClipperLib.use_xyz)
					op2.Pt.Z = Pt.Z
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
				if (ClipperLib.use_xyz)
					op2.Pt.Z = Pt.Z
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
			Pt = Point0!
			DiscardLeftSide = nil
			if (op1.Pt.X >= Left and op1.Pt.X <= Right)
				Pt.X = op1.Pt.X
				Pt.Y = op1.Pt.Y
				if (ClipperLib.use_xyz)
					Pt.Z = op1.Pt.Z
				DiscardLeftSide = (op1.Pt.X > op1b.Pt.X)

			elseif (op2.Pt.X >= Left and op2.Pt.X <= Right)
				Pt.X = op2.Pt.X
				Pt.Y = op2.Pt.Y
				if (ClipperLib.use_xyz)
					Pt.Z = op2.Pt.Z
				DiscardLeftSide = (op2.Pt.X > op2b.Pt.X)

			elseif (op1b.Pt.X >= Left and op1b.Pt.X <= Right)
				--Pt = op1b.Pt;
				Pt.X = op1b.Pt.X
				Pt.Y = op1b.Pt.Y
				if (ClipperLib.use_xyz)
					Pt.Z = op1b.Pt.Z
				DiscardLeftSide = op1b.Pt.X > op1.Pt.X

			else
				Pt.X = op2b.Pt.X
				Pt.Y = op2b.Pt.Y
				if (ClipperLib.use_xyz)
					Pt.Z = op2b.Pt.Z
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

			--Temporary
			Reverse1 = op1b.Pt.Y > op1.Pt.Y or not ClipperLib.ClipperBase.OldSlopesEqual4(op1.Pt, op1b.Pt, j.OffPt, @m_UseFullRange)
			--Reverse1 = ((op1b.Pt.Y > op1.Pt.Y) or not ClipperLib.ClipperBase.SlopesEqual4(op1.Pt, op1b.Pt, j.OffPt))

			if (Reverse1)
				op1b = op1.Prev
				while ((ClipperLib.Point.op_Equality(op1b.Pt, op1.Pt)) and (op1b != op1))
					op1b = op1b.Prev

				--Temporary
				if ((op1b.Pt.Y > op1.Pt.Y) or not ClipperLib.ClipperBase.OldSlopesEqual4(op1.Pt, op1b.Pt, j.OffPt, @m_UseFullRange))
				--if ((op1b.Pt.Y > op1.Pt.Y) or not ClipperLib.ClipperBase.SlopesEqual4(op1.Pt, op1b.Pt, j.OffPt))

					return false

			op2b = op2.Next
			while ((ClipperLib.Point.op_Equality(op2b.Pt, op2.Pt)) and (op2b != op2))
				op2b = op2b.Next

			--Temporary
			Reverse2 = op2b.Pt.Y > op2.Pt.Y or not ClipperLib.ClipperBase.OldSlopesEqual4(op2.Pt, op2b.Pt, j.OffPt, @m_UseFullRange)
			--Reverse2 = ((op2b.Pt.Y > op2.Pt.Y) or not ClipperLib.ClipperBase.SlopesEqual4(op2.Pt, op2b.Pt, j.OffPt))

			if (Reverse2)
				op2b = op2.Prev
				while ((ClipperLib.Point.op_Equality(op2b.Pt, op2.Pt)) and (op2b != op2))
					op2b = op2b.Prev

				--Temporary
				if ((op2b.Pt.Y > op2.Pt.Y) or not ClipperLib.ClipperBase.OldSlopesEqual4(op2.Pt, op2b.Pt, j.OffPt, @m_UseFullRange))
				--if ((op2b.Pt.Y > op2.Pt.Y) or not ClipperLib.ClipperBase.SlopesEqual4(op2.Pt, op2b.Pt, j.OffPt))

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

	FixupFirstLefts1: (OldOutRec, NewOutRec) =>
		outRec, firstLeft = nil
		for i = 1, #@m_PolyOuts
			outRec = @m_PolyOuts[i]
			firstLeft = ClipperLib.Clipper.ParseFirstLeft(outRec.FirstLeft)
			if (outRec.Pts != nil and firstLeft == OldOutRec)
				if (@Poly2ContainsPoly1(outRec.Pts, NewOutRec.Pts))
					outRec.FirstLeft = NewOutRec

	FixupFirstLefts2: (innerOutRec, outerOutRec) =>
		--A polygon has split into two such that one is now the inner of the other.
		--It's possible that these polygons now wrap around other polygons, so check
		--every polygon that's also contained by OuterOutRec's FirstLeft container
		--(including nil) to see if they've become inner to the new inner polygon ...
		orfl = outerOutRec.FirstLeft
		outRec, firstLeft = nil
		for i = 1, #@m_PolyOuts
			outRec = @m_PolyOuts[i]
			if (outRec.Pts == nil or outRec == outerOutRec or outRec == innerOutRec)
				continue
			firstLeft = ClipperLib.Clipper.ParseFirstLeft(outRec.FirstLeft)
			if (firstLeft != orfl and firstLeft != innerOutRec and firstLeft != outerOutRec)
				continue
			if (@Poly2ContainsPoly1(outRec.Pts, innerOutRec.Pts))
				outRec.FirstLeft = innerOutRec
			elseif (@Poly2ContainsPoly1(outRec.Pts, outerOutRec.Pts))
				outRec.FirstLeft = outerOutRec
			elseif (outRec.FirstLeft == innerOutRec or outRec.FirstLeft == outerOutRec)
				outRec.FirstLeft = orfl

	FixupFirstLefts3: (OldOutRec, NewOutRec) =>
		--same as FixupFirstLefts1 but doesn't call Poly2ContainsPoly1()
		outRec = nil
		firstLeft = nil
		for i = 1, #@m_PolyOuts
			outRec = @m_PolyOuts[i]
			firstLeft = ClipperLib.Clipper.ParseFirstLeft(outRec.FirstLeft)
			if (outRec.Pts != nil and firstLeft == OldOutRec)
				outRec.FirstLeft = NewOutRec

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
					if (@m_UsingPolyTree)
						@FixupFirstLefts2(outRec2, outRec1)

					if  (BitXOR(outRec2.IsHole == true and 1 or 0, @ReverseSolution == true and 1 or 0)) == ((@AreaS1(outRec2) > 0) == true and 1 or 0)
						@ReversePolyPtLinks(outRec2.Pts)

				elseif (@Poly2ContainsPoly1(outRec1.Pts, outRec2.Pts))
					--outRec2 contains outRec1 ...
					outRec2.IsHole = outRec1.IsHole
					outRec1.IsHole = not outRec2.IsHole
					outRec2.FirstLeft = outRec1.FirstLeft
					outRec1.FirstLeft = outRec2
					if (@m_UsingPolyTree)
						@FixupFirstLefts2(outRec1, outRec2)

					if  (BitXOR(outRec1.IsHole == true and 1 or 0, @ReverseSolution == true and 1 or 0)) == ((@AreaS1(outRec1) > 0) == true and 1 or 0)
						@ReversePolyPtLinks(outRec1.Pts)

				else
					--the 2 polygons are completely separate ...
					outRec2.IsHole = outRec1.IsHole
					outRec2.FirstLeft = outRec1.FirstLeft
					--fixup FirstLeft pointers that may need reassigning to OutRec2
					if (@m_UsingPolyTree)
						@FixupFirstLefts1(outRec1, outRec2)

			else
				--joined 2 polygons together ...
				outRec2.Pts = nil
				outRec2.BottomPt = nil
				outRec2.Idx = outRec1.Idx
				outRec1.IsHole = holeStateRec.IsHole
				if (holeStateRec == outRec2)
					outRec1.FirstLeft = outRec2.FirstLeft
				outRec2.FirstLeft = outRec1
				--ixup FirstLeft pointers that may need reassigning to OutRec1
				if (@m_UsingPolyTree)
					@FixupFirstLefts3(outRec2, outRec1)

	UpdateOutPtIdxs: (outrec) =>
		op = outrec.Pts
		while true do
			op.Idx = outrec.Idx
			op = op.Prev
			
			if (op == outrec.Pts)
				break

	DoSimplePolygons: =>
		i = 0
		while (i < #@m_PolyOuts)
			outrec = @m_PolyOuts[i + 1]
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
							if (@m_UsingPolyTree)
								@FixupFirstLefts2(outrec2, outrec)

						elseif (@Poly2ContainsPoly1(outrec.Pts, outrec2.Pts))
							--OutRec1 is contained by OutRec2 ...
							outrec2.IsHole = outrec.IsHole
							outrec.IsHole = not outrec2.IsHole
							outrec2.FirstLeft = outrec.FirstLeft
							outrec.FirstLeft = outrec2
							if (@m_UsingPolyTree)
								@FixupFirstLefts2(outrec, outrec2)

						else
							--the 2 polygons are separate ...
							outrec2.IsHole = outrec.IsHole
							outrec2.FirstLeft = outrec.FirstLeft
							if (@m_UsingPolyTree)
								@FixupFirstLefts1(outrec, outrec2)

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
			
			if(op != opFirst) -- and typeof op !== 'undefined')
				break

		return a * 0.5

	AreaS1: (outRec) =>
		return @Area(outRec.Pts)

ClipperLib.ClipperOffset.GetUnitNormal = (pt1, pt2) ->
	dx = (pt2.X - pt1.X)
	dy = (pt2.Y - pt1.Y)
	if ((dx == 0) and (dy == 0))
		return DoublePoint2(0, 0)
	f = 1 / math.sqrt(dx * dx + dy * dy)
	dx *= f
	dy *= f
	return DoublePoint2(dy, -dx)

class ClipperOffset
	new: (miterLimit, arcTolerance) =>
		@m_destPolys = Paths!
		@m_srcPoly = Path!
		@m_destPoly = Path!
		@m_normals = {}
		@m_delta = 0
		@m_sinA = 0
		@m_sin = 0
		@m_cos = 0
		@m_miterLim = 0
		@m_StepsPerRad = 0
		@m_lowest = Point0!
		@m_polyNodes = PolyNode!
		@MiterLimit = miterLimit or 2
		@ArcTolerance = arcTolerance or ClipperLib.ClipperOffset.def_arc_tolerance
		@m_lowest.X = -1

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
			@m_lowest = Point2(@m_polyNodes\ChildCount(), k)
		else
			ip = @m_polyNodes\Childs()[@m_lowest.X].m_polygon[@m_lowest.Y]
			if (newNode.m_polygon[k].Y > ip.Y or (newNode.m_polygon[k].Y == ip.Y and newNode.m_polygon[k].X < ip.X))
				@m_lowest = Point2(@m_polyNodes\ChildCount(), k)

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
					ClipperLib.reverse(node.m_polygon)
		else
			for i = 1, @m_polyNodes\ChildCount()
				node = @m_polyNodes\Childs()[i]
				if (node.m_endtype == ClipperLib.EndType.etClosedLine and not ClipperLib.Clipper.Orientation(node.m_polygon))
					ClipperLib.reverse(node.m_polygon)

	DoOffset: (delta) =>
		@m_destPolys = {}
		@m_delta = delta
		--if Zero offset, just copy any CLOSED polygons to m_p and return ...
		if (ClipperLib.ClipperBase.near_zero(delta))
			--@m_destPolys.set_Capacity(@m_polyNodes.ChildCount);
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
		--@m_destPolys.set_Capacity(@m_polyNodes.ChildCount * 2);
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
					for j = 1, steps -- partire da 2?
						table.insert(@m_destPoly, Point2(@m_srcPoly[1].X + X * delta, @m_srcPoly[1].Y + Y * delta))
						X2 = X
						X = X * @m_cos - @m_sin * Y
						Y = X2 * @m_sin + Y * @m_cos

				else
					X = -1
					Y = -1
					for j = 1, 4
						table.insert(@m_destPoly, Point2(@m_srcPoly[1].X + X * delta, @m_srcPoly[1].Y + Y * delta))	
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
			--@m_normals.set_Capacity(len);
			for j = 1, len - 1
				table.insert(@m_normals, ClipperLib.ClipperOffset.GetUnitNormal(@m_srcPoly[j], @m_srcPoly[j + 1]))

			if (node.m_endtype == ClipperLib.EndType.etClosedLine or node.m_endtype == ClipperLib.EndType.etClosedPolygon)
				table.insert(@m_normals, ClipperLib.ClipperOffset.GetUnitNormal(@m_srcPoly[len], @m_srcPoly[1]))
			else
				table.insert(@m_normals, DoublePoint1(@m_normals[len - 1]))

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
					@m_normals[j] = DoublePoint2(-@m_normals[j - 1].X, -@m_normals[j - 1].Y)
				@m_normals[1] = DoublePoint2(-n.X, -n.Y)
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
					pt1 = Point2(@m_srcPoly[j].X + @m_normals[j].X * delta, @m_srcPoly[j].Y + @m_normals[j].Y * delta)
					table.insert(@m_destPoly, pt1)
					pt1 = Point2(@m_srcPoly[j].X - @m_normals[j].X * delta, @m_srcPoly[j].Y - @m_normals[j].Y * delta)
					table.insert(@m_destPoly, pt1)
				else
					j = len
					k = len - 1
					@m_sinA = 0
					@m_normals[j] = DoublePoint2(-@m_normals[j].X, -@m_normals[j].Y)
					if (node.m_endtype == ClipperLib.EndType.etOpenSquare)
						@DoSquare(j, k)
					else
						@DoRound(j, k)

				--re-build m_normals ...
				for j = len, 2, -1
					@m_normals[j] = DoublePoint2(-@m_normals[j - 1].X, -@m_normals[j - 1].Y)
				@m_normals[1] = DoublePoint2(-@m_normals[2].X, -@m_normals[2].Y)
				k = len
				for j = k - 1, 2, -1
					k = @OffsetPoint(j, k, node.m_jointype)
				if (node.m_endtype == ClipperLib.EndType.etOpenButt)
					pt1 = Point2(@m_srcPoly[1].X - @m_normals[1].X * delta, @m_srcPoly[1].Y - @m_normals[1].Y * delta)
					table.insert(@m_destPoly, pt1)
					pt1 = Point2(@m_srcPoly[1].X + @m_normals[1].X * delta, @m_srcPoly[1].Y + @m_normals[1].Y * delta)
					table.insert(@m_destPoly, pt1)
				else
					k = 1
					@m_sinA = 0
					if (node.m_endtype == ClipperLib.EndType.etOpenSquare)
						@DoSquare(1, 2)
					else
						@DoRound(1, 2)

				table.insert(@m_destPolys, @m_destPoly)

	Execute: (...) =>
		a = {...}
		ispolytree = a[1].class_name == "PolyTree"
		test = nil
		if (not ispolytree) -- function (solution, delta)
			solution = a[1]
			delta = a[2]
			ClipperLib.Clear(solution)
			@FixOrientations!
			@DoOffset(delta)
			-- now clean up 'corners' ...
			clpr = Clipper!
			clpr\AddPaths(@m_destPolys, ClipperLib.PolyType.ptSubject, true)
			if (delta > 0)
				succeded, test = clpr\Execute(ClipperLib.ClipType.ctUnion, solution, ClipperLib.PolyFillType.pftPositive, ClipperLib.PolyFillType.pftPositive)
			else
				r = ClipperLib.Clipper.GetBounds(@m_destPolys)
				outer = Path!
				table.insert(outer, Point2(r.left - 10, r.bottom + 10))
				table.insert(outer, Point2(r.right + 10, r.bottom + 10))
				table.insert(outer, Point2(r.right + 10, r.top - 10))
				table.insert(outer, Point2(r.left - 10, r.top - 10))
				clpr\AddPath(outer, ClipperLib.PolyType.ptSubject, true)
				clpr.ReverseSolution = true
				succeded, test = clpr\Execute(ClipperLib.ClipType.ctUnion, solution, ClipperLib.PolyFillType.pftNegative, ClipperLib.PolyFillType.pftNegative)
				if (#test > 1)
					table.remove(test, 1)

		else -- function (polytree, delta)
			solution = a[1]
			delta = a[2]
			ClipperLib.Clear(solution)
			@FixOrientations!
			@DoOffset(delta)
			--now clean up 'corners' ...
			clpr = Clipper!
			clpr\AddPaths(@m_destPolys, ClipperLib.PolyType.ptSubject, true)
			if (delta > 0)
				clpr\Execute(ClipperLib.ClipType.ctUnion, solution, ClipperLib.PolyFillType.pftPositive, ClipperLib.PolyFillType.pftPositive)
			else
				r = ClipperLib.Clipper.GetBounds(@m_destPolys)
				outer = Path!
				table.insert(outer, Point2(r.left - 10, r.bottom + 10))
				table.insert(outer, Point2(r.right + 10, r.bottom + 10))
				table.insert(outer, Point2(r.right + 10, r.top - 10))
				table.insert(outer, Point2(r.left - 10, r.top - 10))
				clpr\AddPath(outer, ClipperLib.PolyType.ptSubject, true)
				clpr.ReverseSolution = true
				clpr\Execute(ClipperLib.ClipType.ctUnion, solution, ClipperLib.PolyFillType.pftNegative, ClipperLib.PolyFillType.pftNegative)
				--remove the outer PolyNode rectangle ...
				if (solution.ChildCount() == 1 and solution.Childs()[1].ChildCount() > 0)
					outerNode = solution.Childs()[1]
					--solution.Childs.set_Capacity(outerNode.ChildCount);
					solution.Childs()[1] = outerNode.Childs()[1]
					solution.Childs()[1].m_Parent = solution
					for i = 1, outerNode.ChildCount()
						solution.AddChild(outerNode.Childs()[i])
				else
					ClipperLib.Clear(solution)
		return test

	OffsetPoint: (j, k, jointype) =>
		--cross product ...
		@m_sinA = (@m_normals[k].X * @m_normals[j].Y) - (@m_normals[j].X * @m_normals[k].Y)
		

		--Temporary
		if (math.abs(@m_sinA * @m_delta) < 1.0)
			--dot product ...
			cosA = (@m_normals[k].X * @m_normals[j].X + @m_normals[j].Y * @m_normals[k].Y)
			if (cosA > 0) -- angle ==> 0 degrees
				table.insert(@m_destPoly, Point2(@m_srcPoly[j].X + @m_normals[k].X * @m_delta, @m_srcPoly[j].Y + @m_normals[k].Y * @m_delta))
				return k


		--if (@m_sinA == 0)
			--return k

		elseif (@m_sinA > 1)
			@m_sinA = 1.0
		elseif (@m_sinA < -1)
			@m_sinA = -1.0
		if (@m_sinA * @m_delta < 0)
			table.insert(@m_destPoly, Point2(@m_srcPoly[j].X + @m_normals[k].X * @m_delta, @m_srcPoly[j].Y + @m_normals[k].Y * @m_delta))
			table.insert(@m_destPoly, Point1(@m_srcPoly[j]))
			table.insert(@m_destPoly, Point2(@m_srcPoly[j].X + @m_normals[j].X * @m_delta, @m_srcPoly[j].Y + @m_normals[j].Y * @m_delta))

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
		table.insert(@m_destPoly, Point2(@m_srcPoly[j].X + @m_delta * (@m_normals[k].X - @m_normals[k].Y * dx), @m_srcPoly[j].Y + @m_delta * (@m_normals[k].Y + @m_normals[k].X * dx)))
		table.insert(@m_destPoly, Point2(@m_srcPoly[j].X + @m_delta * (@m_normals[j].X + @m_normals[j].Y * dx), @m_srcPoly[j].Y + @m_delta * (@m_normals[j].Y - @m_normals[j].X * dx)))

	DoMiter: (j, k, r) =>
		q = @m_delta / r
		table.insert(@m_destPoly, Point2(@m_srcPoly[j].X + (@m_normals[k].X + @m_normals[j].X) * q, @m_srcPoly[j].Y + (@m_normals[k].Y + @m_normals[j].Y) * q))
	
	DoRound: (j, k) =>
		a = math.atan2(@m_sinA, @m_normals[k].X * @m_normals[j].X + @m_normals[k].Y * @m_normals[j].Y)

		steps = math.max(math.floor(@m_StepsPerRad * math.abs(a), 0))

		X = @m_normals[k].X
		Y = @m_normals[k].Y
		X2 = nil
		for i = 1, steps
			table.insert(@m_destPoly, Point2(@m_srcPoly[j].X + X * @m_delta, @m_srcPoly[j].Y + Y * @m_delta))
			X2 = X
			X = X * @m_cos - @m_sin * Y
			Y = X2 * @m_sin + Y * @m_cos

		table.insert(@m_destPoly, Point2(@m_srcPoly[j].X + @m_normals[j].X * @m_delta, @m_srcPoly[j].Y + @m_normals[j].Y * @m_delta))

--------------------------------------------------------------------------

class Matrix
	new: (pts) =>
		@pts = pts
		@result = {}

	Reset: =>
		@matrix = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1}

	matrix: {1, 0, 0, 0,
			 0, 1, 0, 0,
			 0, 0, 1, 0,
			 0, 0, 0, 1}

	Multiply: (matrix2) =>

		new_matrix = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}

		for i = 1, 16
			for j = 0, 3
				new_matrix[i] = new_matrix[i] + @matrix[1 + (i - 1) % 4 + j * 4] * matrix2[1 + math.floor((i - 1) / 4) * 4 + j]

		@matrix = new_matrix


	Traslate: (x, y, z) =>
		@Multiply({1, 0, 0, 0,
					0, 1, 0, 0,
					0, 0, 1, 0,
					x, y, z, 1})

	RotateX: (angle) =>
		angle = math.rad(angle)
		@Multiply({1, 0, 0, 0,
					0, math.cos(angle), -math.sin(angle), 0,
					0, math.sin(angle), math.cos(angle), 0,
					0, 0, 0, 1})

	RotateY: (angle) =>
		angle = math.rad(angle)
		@Multiply({math.cos(angle), 0, math.sin(angle), 0,
					0, 1, 0, 0,
					-math.sin(angle), 0, math.cos(angle), 0,
					0, 0, 0, 1})

	RotateZ: (angle) =>
		angle = math.rad(angle)
		@Multiply({math.cos(angle), -math.sin(angle), 0, 0,
					math.sin(angle), math.cos(angle), 0, 0,
					0, 0, 1, 0,
					0, 0, 0, 1})

	Scale: (sx, sy, sz) =>
		sx = sx / 100
		sy = sy / 100 
		sz = 1 if sz == nil or sz / 100
		@Multiply({sx, 0, 0, 0,
					0, sy, 0, 0,
					0, 0, sz, 0,
					0, 0, 0, 1})

	Shear: (fax, fay) =>
		@Multiply({1, fay, 0, 0,
					fax, 1, 0, 0,
					0, 0, 1, 0,
					0, 0, 0, 1})

	Transform: =>
		z = 0
		w = 1
		for i = 1, #@pts
			table.insert(@result, {})
			for j = 1, #@pts[i]
				table.insert(@result[i], {X:(@pts[i][j].X * @matrix[1] + @pts[i][j].Y * @matrix[5] + z * @matrix[9] + w * @matrix[13]), Y:(@pts[i][j].X * @matrix[2] + @pts[i][j].Y * @matrix[6] + z * @matrix[10] + w * @matrix[14])})
		--@pts.X = (@pts.X * @matrix[1] + @pts.Y * @matrix[5] + z * @matrix[9] + w * @matrix[13])
		--@pts.Y = (@pts.X * @matrix[2] + @pts.Y * @matrix[6] + z * @matrix[10] + w * @matrix[14])
		--@pts.Z = (@pts[i].X * @matrix[3] + @pts[i].Y * @matrix[7] + @pts[i].Z * @matrix[11] + w * @matrix[15])
		--@pts.W = (@pts[i].X * @matrix[4] + @pts[i].Y * @matrix[8] + @pts[i].Z * @matrix[12] + w * @matrix[16])

		@Reset!

Aegihelp = {}

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

	return strs

Aegihelp.GetLine = (line) ->

	clip = line\match("\\i?clip%b()")

	if clip != nil and clip\match("([%d.-]+),([%d.-]+),([%d.-]+),([%d.-]+)")
		a, b, c, d = line\match("([%d.-]+),([%d.-]+),([%d.-]+),([%d.-]+)")
		clip = string.format("m %d %d l %d %d %d %d %d %d", a, b, c, b, c, d, a, d)
	
	if clip != nil
		clip = clip\gsub("\\i?clip%(", "")
		clip = clip\gsub("%)", "")

	shape = nil
	if line\match("^{[^}]-\\p1")
		shape = line\match("}([^{]+)")

	return {
		clip: clip,
		shape: shape,
		family: line\match("\\fn([^\\]+)") or "Arial",
		bold: line\match("\\b1") and true or false,
		italic: line\match("\\i1") and true or false,
		underline: line\match("\\u1") and true or false,
		strikeout: line\match("\\s1") and true or false,
		size: line\match("^{[^}]-\\fs([%d%.%-]+)") or 50,
		xscale: line\match("^{[^}]-\\fscx([%d%.%-]+)") or 100,
		yscale: line\match("^{[^}]-\\fscy([%d%.%-]+)") or 100,
		hspace: line\match("^{[^}]-\\fsp([%d%.%-]+)") or 0,
		frx: line\match("^{[^}]-\\frx([%d%.%-]+)") or 0,
		fry: line\match("^{[^}]-\\fry([%d%.%-]+)") or 0,
		frz: line\match("^{[^}]-\\frz([%d%.%-]+)") or 0,
		fax: line\match("^{[^}]-\\fax([%d%.%-]+)") or 0,
		fay: line\match("^{[^}]-\\fay([%d%.%-]+)") or 0,
		text: line\gsub("%b{}",""),
		pos: {
			x: line\match("\\pos%(([%d.-]+),") or 0,
			y: line\match("\\pos%([%d.-]+,([%d.-]+)") or 0
		},
		shad: line\match("^{[^}]-\\shad([%d%.%-]+)") or nil
	}

Aegihelp.TextToShape = (data) ->
	textshape = Yutils.decode.create_font(data.family, data.bold, data.italic, data.underline, data.strikeout, tonumber(data.size), tonumber(data.xscale) / 100, tonumber(data.yscale) / 100, tonumber(data.hspace)).text_to_shape(data.text)
	center = Aegihelp.FindCenter(textshape)
	textshape = Yutils.shape.move(textshape, -(tonumber(center.x)), -(tonumber(center.y)))
	return textshape

Aegihelp.FindCenter = (polygon) ->
	polygon = Yutils.shape.flatten(polygon)
	points = {}
	for x, y in polygon\gmatch("([-%d.]+).([-%d.]+)")
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

GUI = {
	main: {
		{class: "label", label: "Pathfinder", x: 1, y: 0},
		{class: "dropdown", name: "pathfinder", value: "Union", items: {"Union", "Intersect", "Difference", "XOR"}, x: 0, y: 0},
		{class: "dropdown", name: "subjectfilltype", value: "NonZero", items: {"NonZero", "EvenOdd"}, x: 0, y: 1},
		{class: "label", label: "Subject FillType", x: 1, y: 1},
		{class: "dropdown", name: "clipfilltype", value: "NonZero", items: {"NonZero", "EvenOdd"}, x: 0, y: 2},
		{class: "label", label: "Clip FillType", x: 1, y: 2},

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
		{class: "floatedit", name: "gradientsize", x: 6, y: 7, width: 1, height: 1, hint: "Gradient size", value: 2}
	},
	help: {
		{class: "textbox", x: 0, y: 0, width: 45, height: 15, value: Helptext}
	}
}

Main = (sub, sel) ->
	run, res = aegisub.dialog.display(GUI.main, {"Pathfinder", "Offsetting", "Others", "Gradient", "Help", "Exit"}, {close: "Exit"})

	if run == "Help"
		run, res = aegisub.dialog.display(GUI.help, {"Shapery", "Exit"}, {close: "Exit"})
		if run == "Shapery"
			run, res = aegisub.dialog.display(GUI.main, {"Pathfinder", "Offsetting", "Others", "Gradient", "Help", "Exit"}, {close: "Exit"})

	for si, li in ipairs(sel)
		line = sub[li]
		data = Aegihelp.GetLine(line.text)

		ft1 = res.subjectfilltype == "EvenOdd" and ClipperLib.PolyFillType.pftEvenOdd or ClipperLib.PolyFillType.pftNonZero
		ft2 = res.clipfilltype == "EvenOdd" and ClipperLib.PolyFillType.pftEvenOdd or ClipperLib.PolyFillType.pftNonZero

		if run == "Pathfinder"
			if data.clip != nil
				data.clip = data.clip\gsub("clip%(", "")\gsub("%)", "")
				data.clip = Yutils.shape.move(data.clip, -data.pos.x, -data.pos.y)
			
			cpr = Clipper!
			cpr\AddPaths(Aegihelp.AegiToClipper(data.shape), ClipperLib.PolyType.ptSubject, true)
			cpr\AddPaths(Aegihelp.AegiToClipper(data.clip), ClipperLib.PolyType.ptClip, true)
			solution_paths = Paths!

			if res.pathfinder == "Union"
				suc, solution_paths = cpr\Execute(ClipperLib.ClipType.ctUnion, solution_paths, ft1, ft2)
			if res.pathfinder == "Intersect"
				suc, solution_paths = cpr\Execute(ClipperLib.ClipType.ctIntersection, solution_paths, ft1, ft2)
			if res.pathfinder == "Difference"
				suc, solution_paths = cpr\Execute(ClipperLib.ClipType.ctDifference, solution_paths, ft1, ft2)
			if res.pathfinder == "XOR"
				suc, solution_paths = cpr\Execute(ClipperLib.ClipType.ctXor, solution_paths, ft1, ft2)

			line.text = line.text\gsub("\\i?clip%b()", "")
			solution_paths = Aegihelp.ClipperToAegi(solution_paths)
			line.text = line.text\match("%b{}")
			for i = 1, #solution_paths
				line.text = line.text .. solution_paths[i]

			sub[li] = line

		if run == "Offsetting"
			jt, et = nil
			if res.jointype == "Miter"
				jt = ClipperLib.JoinType.jtMiter
			elseif res.jointype == "Round"
				jt = ClipperLib.JoinType.jtRound
			elseif res.jointype == "Square"
				jt = ClipperLib.JoinType.jtSquare

			if res.endtype == "ClosedPolygon"
				et = ClipperLib.EndType.etClosedPolygon
			elseif res.endtype == "ClosedLine"
				et = ClipperLib.EndType.etClosedLine

			solution = Paths!
			co = ClipperOffset(res.miterLimit, res.arcTolerance)
			co\AddPaths(Aegihelp.AegiToClipper(data.shape), jt, et)
			solution = co\Execute(solution, res.delta)

			line.text = line.text\match("%b{}")
			solution = Aegihelp.ClipperToAegi(solution)
			for i = 1, #solution
				line.text = line.text .. solution[i]

			sub[li] = line

		if run == "Others"
			if res.others == "Text to Shape"
				textshape = Aegihelp.TextToShape(data)
				line.text = "{\\an7\\blur0\\bord0\\shad0\\fscx100\\fscy100\\pos(" .. data.pos.x .. "," .. data.pos.y .. ")\\p1}" .. textshape
				sub[li] = line

			if res.others == "Move Shape"
				shape = Yutils.shape.move(data.shape, res.horizontal, res.vertical)
				line.text = line.text\match("%b{}") .. shape
				sub[li] = line

			if res.others == "Inner Shadow"
				shape = nil
				shadowline = line

				if res.convert
					shape = Aegihelp.TextToShape(data)
					line.text = "{\\an7\\blur0\\bord0\\shad0\\fscx100\\fscy100\\pos(" .. data.pos.x .. "," .. data.pos.y .. ")\\p1}" .. shape
					center = Aegihelp.FindCenter(shape)
					shape = Yutils.shape.move(shape, -(tonumber(center.x)), -(tonumber(center.y)))
				else
					shape = data.shape
				
				cpr = Clipper!
				cpr\AddPaths(Aegihelp.AegiToClipper(shape), ClipperLib.PolyType.ptSubject, true)
				cpr\AddPaths(Aegihelp.AegiToClipper(Yutils.shape.move(shape, res.horizontal, res.vertical)), ClipperLib.PolyType.ptClip, true)
				solution_paths = Paths!
				succeeded, solution_paths = cpr\Execute(ClipperLib.ClipType.ctDifference, solution_paths, ft1, ft2)

				shadowline.text = "{\\an7\\blur0\\bord0\\shad0\\fscx100\\fscy100\\pos(" .. data.pos.x .. "," .. data.pos.y .. ")\\p1}"
				solution_paths = Aegihelp.ClipperToAegi(solution_paths)
				for i = 1, #solution_paths
					shadowline.text = shadowline.text .. solution_paths[i]

				sub.insert(li, shadowline)
				sub[li] = line

			if res.others == "Center Shape"
				center = Aegihelp.FindCenter(data.shape)
				shape = Yutils.shape.move(data.shape, -center.x, -center.y)
				line.text = line.text\match("%b{}") .. shape
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

					return points

			find_perpendicular_points = (p1, p2, distance) ->
				x1, y1, x2, y2 = p1[1], p1[2], p2[1], p2[2]
				dx = x2-x1
				dy = y2-y1

				mx = (x2+x1)/2
				my = (y2+y1)/2

				L = math.sqrt(dx * dx + dy * dy)

				U = {x: -dy / L, y: dx / L}

				x = Round(mx + U.x * distance, 4)
				y = Round(my + U.y * distance, 4)
				xx = Round(mx - U.x * distance, 4)
				yy = Round(my - U.y * distance, 4)
				
				toreturn = "m " .. x .. " " .. y .. " l " .. xx .. " " .. yy
				return toreturn

			funzione = (a) ->
				str = ""
				for i = 1, #a
					str = str .. "m "
					for j = 1, #a[i]
						if j == 2
							str = str .. "l " .. tostring(a[i][j].X) .. " " .. tostring(a[i][j].Y) .. " "
						else
							str = str .. tostring(a[i][j].X) .. " " .. tostring(a[i][j].Y) .. " "

				return str

			split = split_line(Aegihelp.GetLine(line.text).clip)--data.clip)

			perp_line = {}
			for i = 1, #split - 1
				table.insert(perp_line, find_perpendicular_points(split[i], split[i + 1], 2000))

			if res.gradientsize <= 1 then res.gradientsize = 1

			perp_lines_expanded = {}
			for i = 1, #perp_line
				solution = Paths!
				co = ClipperOffset(2, 0.25)
				co\AddPaths(Aegihelp.AegiToClipper(perp_line[i]), ClipperLib.JoinType.jtMiter, ClipperLib.EndType.etOpenButt)
				expanded_line = co\Execute(solution, res.gradientsize / 2 + res.gradientsize)
				table.insert(perp_lines_expanded, funzione(expanded_line))

			--creazione colori
			hex_to_dec = (str) ->
				a, b = str\match("(.)(.)")
				switch a
					when "A" or "a"
						a = 10
					when "B" or "b"
						a = 11
					when "C" or "c"
						a = 12
					when "D" or "d"
						a = 13
					when "E" or "e"
						a = 14
					when "F" or "f"
						a = 15
					else
						a = tonumber(a)

				switch b
					when "A" or "a"
						b = 10 
					when "B" or "b"
						b = 11
					when "C" or "c"
						b = 12
					when "D" or "d"
						b = 13
					when "E" or "e"
						b = 14
					when "F" or "f"
						b = 15
					else
						b = tonumber(b)

				a = a * 16
				b = b * 1
				return a + b

			dec_to_hex = (num) ->
				hexval = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"}
				a = num / 16
				b = (a - math.floor(a)) * 16

				a = hexval[math.floor(a)]
				b = hexval[b]
				if a == nil then a = 0
				if b == nil then b = 0
				return tostring(a) .. tostring(b)


			class RGB
				new: (r, g, b) =>
					@r = r or 0
					@g = g or 0
					@b = b or 0

			interpolate = (start_c, end_c, num, result) ->
				red = math.abs(start_c.r - end_c.r) / (num - 2)
				invert_red = false if start_c.r < end_c.r else true

				green = math.abs(start_c.g - end_c.g) / (num - 2)
				invert_green = false if start_c.g < end_c.g else true

				blue = math.abs(start_c.b - end_c.b) / (num - 2)
				invert_blue = false if start_c.b < end_c.b else true

				current_c = RGB()
				for i = 1, num
					if i == 1
						current_c = RGB(start_c.r, start_c.g, start_c.b)
					elseif i == num
						current_c = RGB(end_c.r, end_c.g, end_c.b)
					else
						current_c = RGB(invert_red == false and current_c.r + red or current_c.r - red, invert_green == false and current_c.g + green or current_c.g - green, invert_blue == false and current_c.b + blue or current_c.b - blue)

					table.insert(result, "\\c&H" .. dec_to_hex(Round(current_c.b, 0)) .. dec_to_hex(Round(current_c.g, 0)) .. dec_to_hex(Round(current_c.r, 0)) .. "&")

				return result

			col = {}
			for i = 0, #sel - 1
				clrline = sub[li + i]
				blue = clrline.text\match("^{[^}]-\\c&H(..)....&") or "FF"
				green = clrline.text\match("^{[^}]-\\c&H..(..)..&") or "FF"
				red = clrline.text\match("^{[^}]-\\c&H....(..)&") or "FF"
				table.insert(col, RGB(hex_to_dec(red), hex_to_dec(green), hex_to_dec(blue)))

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
				cpr\AddPaths(Aegihelp.AegiToClipper(Yutils.shape.move(perp_lines_expanded[i], -data.pos.x, -data.pos.y)), ClipperLib.PolyType.ptClip, true)
				solution_paths = Paths!
				succeeded, solution_paths = cpr\Execute(ClipperLib.ClipType.ctIntersection, solution_paths, ft1, ft2)
				solution_paths = Aegihelp.ClipperToAegi(solution_paths)
				gradline = line
				gradline.text = line.text\match("%b{}")
				gradline.text = gradline.text\gsub("\\i?clip%b()", "")
				gradline.text = gradline.text\gsub("\\c&H......&", "")
				gradline.text = gradline.text\gsub("{", "{" .. risultato_colori[i])
				for i = 1, #solution_paths
					gradline.text = gradline.text .. solution_paths[i]
				if Aegihelp.GetLine(gradline.text).shape == nil
					continue
				sub.insert(li + i2 + #col, gradline)
				i2 += 1


			--comment all the other lines
			for i = 0, #col - 1
				line = sub[li + i]
				line.comment = true
				sub[li + i] = line
			break

ClipToShape = (sub, sel) ->
	for si, li in ipairs(sel)
		line = sub[li]
		data = Aegihelp.GetLine(line.text)
		line.text = "{\\an7\\blur1\\bord0\\shad0\\fscx100\\fscy100\\pos(0,0)\\p1}" .. data.clip
		sub[li] = line

ShapeToClip = (sub, sel) ->
	for si, li in ipairs(sel)
		line = sub[li]
		data = Aegihelp.GetLine(line.text)
		if data.pos.x != 0 or data.pos.y != 0
			data.shape = Yutils.shape.move(data.shape, tonumber(data.pos.x), tonumber(data.pos.y))
		line.text = line.text\gsub("\\i?clip%b()", "")
		line.text = line.text\gsub("}", "\\clip(" .. data.shape .. ")}")
		sub[li] = line

Expand = (sub, sel) ->
	for si, li in ipairs(sel)
		line = sub[li]
		data = Aegihelp.GetLine(line.text)
		matrix = Matrix(Aegihelp.AegiToClipper(data.shape))
		if data.fax != 0 or data.fay != 0
			matrix\Shear(data.fax, data.fay)
			line.text = line.text\gsub("\\fax[%d%.%-]+", "")
			line.text = line.text\gsub("\\fay[%d%.%-]+", "")
		if data.xscale != 100 or data.yscale != 100
			matrix\Scale(data.xscale, data.yscale, 100)
			line.text = line.text\gsub("\\fscx[%d%.%-]+", "")
			line.text = line.text\gsub("\\fscy[%d%.%-]+", "")

		matrix\Transform!

		shape = Aegihelp.ClipperToAegi(matrix.result)
		finalshape = ""
		for i = 1, #shape
			finalshape = finalshape .. shape[i]
		line.text = line.text\match("%b{}")
		line.text = line.text .. finalshape
		sub[li] = line


aegisub.register_macro(script_name, script_description, Main)
aegisub.register_macro(": Shapery macros :/Clip To Shape", "Convert clip to shape", ClipToShape)
aegisub.register_macro(": Shapery macros :/Shape To Clip", "Convert shape to clip", ShapeToClip)
aegisub.register_macro(": Shapery macros :/Expand", "", Expand)
