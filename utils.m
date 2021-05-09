(* # Mathematica utility belt (`utils.m`)
 *
 * ## Contents
 * [[table of contents]]
 *
 * ## Misc
 *)

LessOrEqualQ[a_, b_] := OrderedQ[{a, b}]
LessQ[a_, b_] := Not[OrderedQ[{b, a}]]

(* Flatten, join, and convert the arguments to a string. *)
MkString[args__] := args // List // Flatten // Map[ToString] // StringJoin

(* Convert the arguments into a string, and that into an expression. *)
MkExpression[args__] := MkString[args] // ToExpression

(* Convert the items into a string, and write it into a given file object. *)
WrString[f_, items__] := {items} // Flatten // Map[BinaryWrite[f, # // ToString]&]

(* Convert the items to string and write it into the file. *)
MkFile[filename_, items__] := Module[{fd},
  (* The BinaryFormat is needed for the BinaryWrite in WrString. *)
  fd = OpenWrite[MkString[filename], BinaryFormat->True];
  If[fd === $Failed, Error["MkFile: failed to open ", filename, " for writing"]];
  WrString[fd, {items}];
  Close[fd];
]

(* Highlight a matching pattern in red. Useful during development
 * inside the GUI. *)
Highlight[pat_] := ReplaceAll[e : pat :> Style[e, Red, Bold]]
Highlight[pat_, style__] := ReplaceAll[e : pat :> Style[e, style]]

(* Print a list, each element on its own line with an index. *)
PrintIndexed[ex_List] := (ex // MapIndexed[Print[#2//First, ") ", #1]&]; ex)
PrintIndexed[ex_] := (Print["?) ", ex]; ex)

(* Find all unique occurrences of pat in ex. *)
CaseUnion[ex_List, pat_] := ex // Map[CaseUnion[pat]] // Apply[Join] // Union;
CaseUnion[ex_, pat_] := Cases[ex, pat, {0, Infinity}] // Union
CaseUnion[pat_] := CaseUnion[#, pat]&

(* A safe way to apply replacement rules to a list of items: map a
 * list, replacing each item (non-recursively) with given rules;
 * fail if one of the items matches no replacement pattern. *)
MapReplace[rules__] := Map[Replace[{rules, x_ :> Error["Failed to replace: ", x, ", with rules: ", {rules}[[;;,1]]]}]]

ReallyReplace[{rules__}] := Replace[{rules, x_ :> Error["Failed to replace: ", x]}]
ReallyReplace[rule_] := Replace[{rule, x_ :> Error["Failed to replace: ", x]}]

(* Get the first and the only element in a list, fail if the
 * list is not a single element list. *)
Only[{el_}] := el
Only[l_] := Error["Only: a list of exactly one element expected, got: ", l]

(* Replace each unique object matching `oldpattern` in `ex` to one
 * of the objects from `newlist` (which is assumed to contain
 * enough new objects). *)
RenameUniques[ex_, oldpattern_, newlist_List] := Module[{old, i},
  old = CaseUnion[ex, oldpattern];
  If[Length[old] > Length[newlist], Error["RenameUniques: too few new names given; trying to rename: ", old]];
  ex /. Table[old[[i]] -> newlist[[i]], {i, Length[old]}]
]
RenameUniques[oldpattern_, newlist_List] := RenameUniques[#, oldpattern, newlist]&

(* Same as `Select[items, f]`, but return the indices of the
 * selected items. *)
SelectIndices[items_, f_] := MapIndexed[If[f[#1], #2//First, Nothing]&, items]
SelectIndices[f_] := SelectIndices[#, f]&

(* Return the first index of the given list where `f[element]` is true. *)
ElementIndex[l_List, f_, default_] := FirstPosition[l, _?f, {default}, {1}, Heads->False] // First

(* Return the first index of the given list where `element` is located. *)
IndexOf[l_List, element_, default_] := FirstPosition[l, element, {default}, {1}, Heads->False] // First

(* Apply `f` to every term of a series. *)
MapSeries[f_, 0] := f[0]
MapSeries[f_, Verbatim[SeriesData][x_, x0_, l_List, n1_, n2_, d_]] := SeriesData[x, x0, Map[f, l], n1, n2, d]
MapSeries[f_] := MapSeries[f, #]&
MapSeries[f_, l_List] := Map[MapSeries[f], l]

SeriesLowestPower[l_List] := Map[SeriesLowestPower, l]
SeriesLowestPower[Verbatim[SeriesData][x_, x0_, l_List, n1_, n2_, d_]] := n1/d

SeriesHighestPower[l_List] := Map[SeriesHighestPower, l]
SeriesHighestPower[Verbatim[SeriesData][x_, x0_, l_List, n1_, n2_, d_]] := (n2 - 1)/d

SeriesTermCount[Verbatim[SeriesData][x_, x0_, l_List, n1_, n2_, d_]] := n2 - n1
SeriesTermCount[l_List] := Map[SeriesTermCount, l]

SeriesLeadingTerm[s_SeriesData] := If[s[[3]] === {}, s, s + O[s[[1]]]*s[[1]]^s[[4]]]

(* Return the list of terms in an expression. Zero is considered
 * to have no terms. *)
Terms[ex_Plus] := List @@ ex
Terms[0] := {}
Terms[ex_] := {ex}

(* Return the number of terms in an expression. *)
TermCount[ex_Plus] := Length[ex]
TermCount[0] := 0
TermCount[ex_] := 1

(* Apply a given function to each term in an expression. *)
MapTerms[f_, ex_Plus] := Map[f, ex]
MapTerms[f_, ex_List] := Map[MapTerms[f], ex]
MapTerms[f_, ex_] := f[ex]
MapTerms[f_] := MapTerms[f, #]&

(* Return the list of factors of an expression. *)
Factors[ex_Times] := List @@ ex
Factors[ex_] := {ex}

(* Apply a given function to each factor of an expression. *)
MapFactors[f_, ex_Times] := Map[f, ex]
MapFactors[f_, ex_List] := Map[MapFactors[f], ex]
MapFactors[f_, ex_] := f[ex]
MapFactors[f_] := MapFactors[f, #]&

(* Return True if an expression is a zero matrix, or a zero
 * SparseMatrix. Return False otherwise. *)
ZeroMatrixQ[mx_SparseArray] := Length[mx["NonzeroPositions"]] === 0
ZeroMatrixQ[mx_List] := mx // Flatten // Union // # === {0}&
ZeroMatrixQ[_] := False

(* Read and parse a file, return the expression inside. Automatically
 * handle .gz, .bz2, and .mx files. Fail if no such file exists,
 * or if there is an error reading it. *)
SafeGet[filename_String] := Module[{result},
  result = If[Not[FileExistsQ[filename]],
    $Failed,
    Which[
      StringMatchQ[filename, ___~~".gz"],
        RunThrough["zcat -q '" <> filename <> "' 2>/dev/null", 0] // Replace[Null -> $Failed],
      StringMatchQ[filename, ___~~".bz2"],
        RunThrough["bzcat -q '" <> filename <> "' 2>/dev/null", 0] // Replace[Null -> $Failed],
      StringMatchQ[filename, ___~~".mx"],
        Quiet[Import[filename], {Import::nffil}],
      StringMatchQ[filename, ___],
        Get[filename]
    ]
  ];
  If[MatchQ[result, $Failed],
      Error["Failed to get: ", filename];
  ];
  result
]

SafePut[expr_, filename_String] := Module[{},
  Which[
    StringMatchQ[filename, ___~~".m"],
      Export[filename, expr],
    StringMatchQ[filename, ___~~".mx"],
      Export[filename, expr],
    StringMatchQ[filename, ___],
      Put[expr, filename]
  ];
  If[MatchQ[result, $Failed],
      Error["Failed to get: ", filename];
  ];
]

(* Print the error message and stop the computation. Exit with
 * an error code if running in a script; raise an exception when
 * in GUI. *)
Error[msg__] := If[Length[Cases[$CommandLine, "-script"]] > 0,
    Print["ERROR: ", msg]; Exit[1];
    ,
    Print[Style["ERROR: ", Red, Bold], msg]; Throw[$Failed];
]

(* Fail the computation unless a condition is met. Useful for
 * assetions and unit tests. *)
ClearAll[FailUnless];
SetAttributes[FailUnless, {HoldAll}]
FailUnless[tests___] := Module[{test, idx, result},
  Do[
    test = Extract[Hold[tests], {idx}, HoldForm];
    If[test === HoldForm[Null], Continue[]];
    result = ReleaseHold[test];
    If[result =!= True,
      If[MatchQ[Extract[test, {1,0}, HoldForm], HoldForm[_Symbol]],
        Print["!!! Test: ", Extract[test, {1,0}, HoldForm], " => ", result];
        Print["!!! 1: ", Extract[test, {1,1}, HoldForm]];
        Print["!!! == ", Extract[test, {1,1}]];
        Print["!!! 2: ", Extract[test, {1,2}, HoldForm]];
        Print["!!! == ", Extract[test, {1,2}]];
        ,
        Print["!!! Test: ", test];
        Print["!!!    => ", result];
      ];
      Error["Test failed!"];
    ];
    ,
    {idx, Length[Hold[tests]]}];
];

FormatAmount[units_List] := FormatAmount[#, units]&
FormatAmount[amount_, units_List] := Module[{i, a},
  For[i = 1, i < Length[units] - 1 && amount > units[[i+1,2]]*0.95, i++, True];
  a = amount / units[[i, 2]] // N;
  MkString[NumberForm[a, {Infinity, 3}], units[[i,1]]]
]

(* Format bytes in human-readable format. *)
FormatBytes[amount_] := FormatAmount[amount, {
  {"B", 1}, {"kB", 2^10}, {"MB", 2^20}, {"GB", 2^30}, {"TB", 2^40},
  {"PB", 2^50}, {"EB", 2^60}, {"ZB", 2^70}, {"YB", 2^80}
}]
FormatSeconds[amount_] := FormatAmount[amount, {
  {"s", 1}, {"m", 60}, {"h", 3600}, {"d", 24*3600}, {"w", 7*24*3600},
  {"y", 365*24*3600}
}]

(* Extract the list of leaf elements, map them with the given
 * function, and put them back in. Note that mapfn must return
 * a list of the same size as its input. *)
LeafApply[mapfn_, ex_] := Module[{skeleton, items},
  LeafApply$SkeletonizeCounter = 0;
  {skeleton, items} = Reap[LeafApply$Skeletonize[ex]];
  items = First[items, {}] // mapfn;
  If[NotMatchQ[items, _List], Error["LeafApply: map did not return a list"]];
  skeleton /. LeafApply$SkeletonizePlace[i_] :> items[[i]]
]
LeafApply[mapfn_] := LeafApply[mapfn, #]&
SetAttributes[LeafApply$Skeletonize, {Listable}];
LeafApply$SkeletonizeCounter = 0;
LeafApply$Skeletonize[s_SeriesData] := MapAt[LeafApply$Skeletonize, s, {3}]
LeafApply$Skeletonize[ex_] := (Sow[ex]; LeafApply$SkeletonizeCounter++; LeafApply$SkeletonizePlace[LeafApply$SkeletonizeCounter])

(* Find all parts of ex that match pat, apply mapfn to the list
 * of such parts, put its result back into the expression. Note
 * that mapfn must return a list of the same size as its input.
 *)
SubexpressionApply[mapfn_, ex_, pat_] := Module[{counter, elements, exX, p, X},
  counter = 0;
  elements = <||>;
  exX = ex /. p:pat :> (counter++; elements[counter] = p; X[counter]);
  {keys, elements} = elements // Normal // {#[[;;,1]], #[[;;,2]]}&;
  elements = elements // mapfn;
  If[NotMatchQ[elements, _List], Error["SubexpressionApply: map did not return a list"]];
  elements = MapThread[Rule, {keys, elements}] // Association;
  exX /. X -> elements
]
SubexpressionApply[mapfn_, ex_, pat_:>fn_] := Module[{counter, elements, exX, p, X},
  counter = 0;
  elements = <||>;
  exX = ex /. p:pat :> (counter++; elements[counter] = fn; X[counter]);
  {keys, elements} = elements // Normal // {#[[;;,1]], #[[;;,2]]}&;
  elements = elements // mapfn;
  If[NotMatchQ[elements, _List], Error["SubexpressionApply: map did not return a list"]];
  elements = MapThread[Rule, {keys, elements}] // Association;
  exX /. X -> elements
]

(*
Among a list of sets, find such a sublist such that all other
sets are subsets of these ones. Return the list, and a list of
indices indicating which set belongs to which superset.

Example:

    {{3},{1,2,3},{2,3,1},{2},{1,4,3},{4}}//UniqueSupersetMapping
    > { {{1,2,3}, {1,4,3}}, {1,1,1,1,2,2} }
*)
UniqueSupersetMapping[sets_List, subsetq_:SubsetQ] := Module[{supersets, idx, IdxOf},
  supersets = {};
  IdxOf[set_] := IdxOf[set] = (
    idx = ElementIndex[supersets, subsetq[#, set]&, None];
    If[idx === None,
      supersets = Append[supersets, set // Sort];
      Length[supersets]
      ,
      idx
    ]
  );
  sets // SortBy[Length] // Reverse // MapWithCliProgress[IdxOf];
  {supersets, sets // Map[IdxOf] }
]

SelectFactors[ex_, pat_] := Module[{f},
    f = Factors[ex];
    {
        f // Cases[pat] // Apply[Times],
        f // DeleteCases[pat] // Apply[Times]
    }
]
SelectFactors[pat_] := SelectFactors[#,pat]&

SplitFactors[ex_, pat_] := Module[{f},
    f = Factor[ex];
    {
        Factors[f] // Select[FreeQ[#, pat] &] // Apply[Times],
        Factors[f] // Select[Not[FreeQ[#, pat]] &] // Apply[Times]
    }
]
SplitFactors[pat_] := SplitFactors[#,pat]&

MxApart[mx_, x_] := Module[{mxa, xxlist, xx},
    mxa = Apart[mx, x] // Expand[#, x]& // Map[Terms, #, {2}]& // Map[SplitFactors[#, x]&, #, {3}]&;
    xxlist = mxa[[;; , ;; , ;; , 2]] // Flatten // Union;
    Table[List[
        xx,
        Map[(Cases[#, {k_, xx} :> k] // Apply[Plus]) &, mxa, {2}]
    ], {xx, xxlist}]
]

CoefficientMatrix[vars_List] := CoefficientMatrix[#, vars]&
CoefficientMatrix[ex_List, vars_List] := Module[{mxl},
  mxl = CoefficientArrays[ex, vars];
  Which[
    Length[mxl] === 0,
      Table[0, Length[ex], Length[vars]],
    Length[mxl] === 1,
      FailUnless[ZeroMatrixQ[mxl[[1]]]];
      Table[0, Length[ex], Length[vars]],
    Length[mxl] === 2,
      FailUnless[ZeroMatrixQ[mxl[1]]];
      mxl[[2]] // Normal,
    True,
      Error["CoefficientMatrix: quadratic terms in the expression?"];
  ]
]

(* Check if there is a linear combination of the given polynomials
 * in the given variables that is a zero.
 *)
PolynomialsLinearlyDependentQ[polynomials_List, vars_List] := Module[{coefrules, monomial2index, coefarray},
    coefrules = polynomials // Map[CoefficientRules[#, vars] &] // DeleteCases[{}];
    monomial2index = coefrules[[;; , ;; , 1]] // Apply[Join] // Union // PositionIndex;
    coefarray = coefrules // MapAt[monomial2index, #, {;; , ;; , 1}] & // MapIndexed[MapAt[Prepend[#2 // First], #1, {;; , 1}] &] // Apply[Join] // SparseArray;
    MatrixRank[coefarray] < Length[coefarray]
]

LeadingSign[ex_List] := Map[LeadingSign, ex]
LeadingSign[ex_ /; (FactorTermsList[ex] // First // Negative)] := -1
LeadingSign[ex_] := 1

DropLeadingSign[ex_List] := Map[DropLeadingSign, ex]
DropLeadingSign[ex_ /; (FactorTermsList[ex] // First // Negative)] := -ex
DropLeadingSign[ex_] := ex

(* Expand the expression, and bracket out all parts of terms
 * that have pat in them. Apply coeff to each bracket, and stemf
 * to each prefactor. *)
Bracket[ex_List, pat_, coeff_, stemf_] := Map[Bracket[#, pat, coeff, stemf] &, ex]
Bracket[ex_Rule, pat_, coeff_, stemf_] := Map[Bracket[#, pat, coeff, stemf] &, ex]
Bracket[ex_SeriesData, pat_, coeff_, stemf_] := MapAt[Bracket[#, pat, coeff, stemf] &, ex, 3]
Bracket[ex_, pat_] := Bracket[ex, pat, #&, #&]
Bracket[ex_, pat_, coeff_] := Bracket[ex, pat, coeff, #&]
Bracket[ex_, vars_List, coeff_, stemf_] := Bracket[ex, Alternatives @@ vars, coeff, stemf]
Bracket[ex_, pat_, coeff_, stemf_] :=
  ex // Expand[#, pat]& // Terms // Map[Factors /* (Times @@@ {Cases[#, pat^_.], DeleteCases[#, pat^_.]} &)] //
    GroupBy[First] // Normal //
    Map[stemf[#[[1]]] coeff[Plus @@ #[[2, ;; , 2]]] &] // Apply[Plus]

AntiBracket[ex_List, pat_, coeff_, stemf_] := Map[AntiBracket[#, pat, coeff, stemf] &, ex]
AntiBracket[ex_SeriesData, pat_, coeff_, stemf_] := MapAt[AntiBracket[#, pat, coeff, stemf] &, ex, 3]
AntiBracket[ex_, pat_] := AntiBracket[ex, pat, #&, #&]
AntiBracket[ex_, pat_, coeff_] := AntiBracket[ex, pat, coeff, #&]
AntiBracket[ex_, vars_List, coeff_, stemf_] := AntiBracket[ex, Alternatives @@ vars, coeff, stemf]
AntiBracket[ex_, pat_, coeff_, stemf_] :=
 ex // Expand // Terms // Map[Factors /* (Times @@@ {DeleteCases[#, pat^_.], Cases[#, pat^_.]} &)] // GroupBy[First] // Normal //
    Map[stemf[#[[1]]] coeff[Plus @@ #[[2, ;; , 2]]] &] // Apply[Plus]

(* Print the time it takes to evaluate its argument, and return
 * the result of the evaluation. Useful for ad-hoc profiling.
 *)
SetAttributes[TM, HoldFirst]
TM[ex_] := AbsoluteTiming[ex] // (Print[HoldForm[ex], ": ", #[[1]]//FormatSeconds]; #[[2]]) &

(* Print an expression and return it. Useful for debugging. *)
PR[ex_] := (Print[ex]; ex)

(* Copy an expression to the clipboard, and return it. *)
ClipCopy[ex_] := (
  Put[ex, "/tmp/clipboard.txt"];
  Run["xclip -i -selection clipboard /tmp/clipboard.txt"];
  ex
);

(* A shortcut for `Not[FreeQ[...]]`. *)
NotFreeQ[ex_, pat_, level_] := Not[FreeQ[ex, pat, level]]
NotFreeQ[ex_, pat_] := Not[FreeQ[ex, pat]]
NotFreeQ[pat_] := FreeQ[pat] /* Not

(* A shortcut for `Not[MatchQ[...]]`. *)
NotMatchQ[ex_, pat_] := Not[MatchQ[ex, pat]]
NotMatchQ[pat_] := MatchQ[pat] /* Not

(* Evaluate a given expression many times, for at least a second,
 * and return the average evaluation time. *)
SetAttributes[TimeIt, HoldFirst];
TimeIt[ex_] := Module[{t, niter = 2},
    t = AbsoluteTiming[Do[ex, niter]] // First;
    While[t < 0.9,
        niter = Max[niter*2, 1.1*niter/Max[t, 0.01] // Ceiling];
        t = AbsoluteTiming[Do[ex, niter]] // First;
    ];
    t/niter
]

(* Return a random name of a fresh file of the form prefix.XXXX.suffix.
 * Make sure no file with this name exists.
 *)
MkTemp[prefix_, suffix_] := Module[{i, fn, alphabet},
    alphabet = Characters["abcdefghijklmnopqrstuvwxyz0123456789"];
    While[True,
        i = RandomSample[alphabet, 8];
        fn = FileNameJoin[{$TemporaryDirectory, MkString[prefix, ".", Environment["USER"], ".", $ProcessID, ".", i, suffix]}];
        If[Not[FileExistsQ[fn]], Return[fn]];
    ]]

(* Make sure a directory exists. Create it if it doesn't. *)
EnsureDirectory[dirs__] := Module[{dir},
  Do[Quiet[CreateDirectory[dir], {CreateDirectory::filex}];, {dir, {dirs}}];
]

(* Make sure a directory doesn't exist. Remove it if it does. *)
EnsureNoDirectory[dirs__] := Module[{dir},
  Do[Quiet[DeleteDirectory[dir, DeleteContents->True], {DeleteDirectory::nodir}];, {dir, {dirs}}];
]

(* Make sure a directory exists and has no files inside. *)
EnsureCleanDirectory[dirs__] := Module[{},
  EnsureNoDirectory[dirs];
  EnsureDirectory[dirs];
]

(* Run a command, fail if the exist status is not zero. *)
SafeRun[code__] := Module[{retcode},
  retcode = Run[MkString[code]];
  If[retcode =!= 0,
    Error["SafeRun: command failed with code ", retcode];
  ];
];

(* Evaluate a given text fragment as Mathematica code in a fresh
 * kernel. Return the result.
 *
 * DEPRECATED: the code is wrapped in a Block[] here, and this
 * was a mistake. Please use RunMathProgram instead.
 *)
RunMathCode[code___] := Module[{tmpfile, resfile, math, retcode, result},
  tmpfile = MkTemp["math", ".m"];
  resfile = tmpfile <> ".result.m";
  MkFile[tmpfile, "Put[Block[{},\n\n", code, "\n\n], \"", resfile, "\"];\n"];
  MkString[code]//PR;
  math = Environment["MATH"] /. $Failed -> "math";
  retcode = Run[math <> " -script " <> tmpfile];
  If[retcode =!= 0,
    Error["RunMathCode: mathematica failed with code ", retcode];
  ];
  result = Get[resfile];
  If[result === $Failed,
    Error["RunMathCode: the script did not finish"];
  ];
  DeleteFile[{tmpfile, resfile}];
  result
]

(* Evaluate a given text fragment as Mathematica script in a fresh
 * kernel. Return the value of the `RESULT` variable at the end
 * of the program. Fail if the program aborted before the end.
 *
 * This is useful because some libraries require a clean Mathematica
 * environment, and explode if mixed with any other code.
 *)
RunMathProgram[code___] := Module[{tmpfile, resfile, math, retcode, result},
  tmpfile = MkTemp["math", ".m"];
  resfile = tmpfile <> ".result.m";
  MkFile[tmpfile, "RESULT = Null;\n\n", code, "\n\nPut[RESULT, \"", resfile, "\"];\n"];
  (*MkString[code]//PR;*)
  Run["cat " <> tmpfile];
  math = Environment["MATH"] /. $Failed -> "math";
  retcode = Run[math <> " -script " <> tmpfile];
  If[retcode =!= 0,
    Error["RunMathCode: mathematica failed with code ", retcode];
  ];
  result = Get[resfile];
  If[result === $Failed,
    Error["RunMathCode: the script did not finish"];
  ];
  DeleteFile[{tmpfile, resfile}];
  result
]


(*
 * Progress Indicators
 *)

$CLI = $FrontEnd === Null;

ProgressBar[x_] := Graphics[{
        GrayLevel[0.9], Rectangle[{0, 0}],
        Darker[Brown], Rectangle[{0, 0}, {x, 1}]
    }, AspectRatio -> Full, ImageSize -> {200, 12}, ImagePadding -> {{0, 0}, {3, 0}}
]

ProgressBar[x_, y_] := Graphics[{
        GrayLevel[0.9], Rectangle[{0, 0}],
        Lighter[Orange], Rectangle[{0, 0}, {y, 1}],
        Darker[Brown], Rectangle[{0, 0}, {x, 1}]
    }, AspectRatio -> Full, ImageSize -> {200, 12}, ImagePadding -> {{0, 0}, {3, 0}}
]

ColorBar[colors_] := Graphics[
    Table[{colors[[i]], Rectangle[{i, 0}]}, {i, Length[colors]}],
    AspectRatio -> Full, ImageSize -> {200, 12}, ImagePadding -> {{0, 0}, {3, 0}}
]

MapWithProgress[f_, lst_] := Module[{r, n = 0, m = Length[lst]},
    Monitor[
        Map[(r = f[#]; n++; r) &, lst],
        Refresh[
            Row[{ProgressBar[n/m, (n + 1)/m], MkString[" ", n, "/", m]}],
            TrackedSymbols -> {n}
        ]
    ]
]
MapWithProgress[f_] := MapWithProgress[f, #] &

MapWithCliProgress[f_, items_List] := Module[{result, t0, tx, t, ndone = 0, ntodo = Length[items], bcounts, bfrac},
  t0 = tx = SessionTime[];
  bcounts = items//Map[ByteCount];
  result = Map[(
    result = f[#];
    ndone++;
    t = SessionTime[];
    If[t - tx > 1,
      bfrac = Plus@@bcounts[[;;ndone]]/Plus@@bcounts//N;
      Print["\r\033[KMap: ", ndone, "/", ntodo, " at ", t-t0//FormatSeconds,
        ", bytes: ", NumberForm[100 bfrac, {Infinity, 1}]//ToString,
        "%, eta ", (t-t0)*(1/bfrac-1)//FormatSeconds];
      tx = t;
    ];
    result
  )&, items];
  Print["Map: done ", ntodo, " items in ", t-t0//FormatSeconds];
  result
]
MapWithCliProgress[f_] := MapWithCliProgress[f, #] &

MapAtWithProgress[f_, lst_, lvl_] := Module[{r, n = 0, m = 0},
  MapAt[(m++;) &, lst, lvl];
  Monitor[MapAt[(r = f[#]; n++; r) &, lst, lvl],
   Refresh[
    Row[{ProgressBar[n/m, (n + 1)/m], MkString[" ", n, "/", m]}],
    TrackedSymbols -> {n}]]]

MapAtWithProgress[f_, lvl_] := MapAtWithProgress[f, #, lvl] &

ParallelMapWithProgress[f_, lst_] := Module[{res, r, ns = 0, ne = 0, color, m = Length[lst]},
    SetSharedVariable[ns, ne, color];
    color = Table[GrayLevel[0.9], m];
    SetSharedVariable[ns, ne, color];
    res = Monitor[
        ParallelMap[(
            color[[#[[2, 1]]]] = Lighter[Orange];
            ns++;
            r = f[#[[1]]];
            color[[#[[2, 1]]]] = Darker[Brown];
            ne++;
            r) &, MapIndexed[List, List @@ lst], Method->"FinestGrained"],
        Refresh[Row[{ColorBar[color], MkString[" ", ne, "/", ns, "/", m]}], TrackedSymbols -> {ns, ne}]
    ];
    UnsetShared[ns, ne, color];
    res // Apply[Head[lst]]
]
ParallelMapWithProgress[f_] := ParallelMapWithProgress[f, #] &

$LastStatusTime = AbsoluteTime[];
SetSharedVariable[$LastStatusTime];
Status[msg___] := Module[{t = AbsoluteTime[]}, If[t - $LastStatusTime > 1, $LastStatusTime = t; Print[MkString[msg]]]]

If[$CLI,
PMap[f_, data_] := Module[{tmpfile, todo, result, r, nitems, nstarted, nended, i},
  {nitems, nstarted, nended} = {Length[data], 0, 0};
  $PARALLELDATA = data;
  SetSharedVariable[nstarted, nended];
  Status["PMap: distributing data, ", ByteCount[$PARALLELDATA]//FormatBytes];
  DistributeDefinitions[$PARALLELDATA];
  ClearAll[$PARALLELDATA];
  Status["PMap: distributing definitions..."];
  DistributeDefinitions[Status, nitems, f];
  Status["PMap: mapping..."];
  todo = Table[ParallelSubmit[{i},
     nstarted++;
     r = f[$PARALLELDATA[[i]]];
     nended++;
     Status["PMap: ", nended, "/", nstarted, "/", nitems];
     r
     ], {i, Length[data]}];
  result = WaitAll[todo];
  ParallelEvaluate[ClearAll[$PARALLELDATA]];
  UnsetShared[nstarted, nended];
  Status["PMap: done, ", result//ByteCount//FormatBytes];
  result
]
  ,
PMap[f_, data_] := Module[{tmpfile, todo, result, r, nitems, nstarted, nended, colorbar, i},
  {nitems, nstarted, nended} = {Length[data], 0, 0};
  colorbar = Table[GrayLevel[0.9], nitems];
  SetSharedVariable[nstarted, nended, colorbar];
    $PARALLELDATA = data;
    PrintTemporary["PMap: distributing data, ", ByteCount[$PARALLELDATA]//FormatBytes];
    TM[
   tmpfile = MkTemp["pmap", ".mx"];
   DumpSave[tmpfile, $PARALLELDATA];
   ClearAll[$PARALLELDATA];
   ParallelEvaluate[Get[tmpfile]];
   DeleteFile[tmpfile];
    ];
    (*
      TM[
    DistributeDefinitions[$PARALLELDATA];
    ClearAll[$PARALLELDATA];
      ];
    *)
    PrintTemporary["PMap: distributing definitions"];
    DistributeDefinitions[f];
  Monitor[
   (*tmpfile = MkTemp["pmap", ".mx"];
   $PARALLELDATA = data;
   DumpSave[tmpfile, $PARALLELDATA];
   ClearAll[$PARALLELDATA];
   ParallelEvaluate[Get[tmpfile]];
   DeleteFile[tmpfile];*)
   todo = Table[ParallelSubmit[{i},
      colorbar[[i]] = Lighter[Orange]; nstarted++;
      r = f[$PARALLELDATA[[i]]]; colorbar[[i]] = Darker[Brown];
      nended++; r
      ], {i, Length[data]}];
   result = WaitAll[todo];
   ParallelEvaluate[ClearAll[$PARALLELDATA]];
   UnsetShared[nstarted, nended, colorbar];
   ,
   Refresh[
    Row[{ColorBar[colorbar],
      MkString[" ", nended, "/", nstarted, "/", nitems]}],
    TrackedSymbols -> {nstarted, nended}]
   ];
  result
  ]
]
PMap[f_] := PMap[f, #] &

(* ## B Maps
 *
 * B maps are a way to apply many substitution rules for `B[...]`
 * objects, as efficiently as Mathematica allows for.
 *)

(* Load substitution rules from a file and add them to a B map
 * identified by a given name (symbol). The file should be in
 * Mathematica format: a list of `B[...] -> ...` rules. Duplicate
 * rules are allowed; conflicting rules will be detected. *)
BMapLoad[name_Symbol, filename_String] := BMapLoad[name, SafeGet[filename]]

(* Add substitution rules to a B map. Check for conflicting
 * rules. *)
BMapLoad[name_Symbol, map_List] := Module[{args, rule, k, v, k0, v0, ndups},
    ndups = 0;
    Do[
        If[Not[MatchQ[rule, _B -> _]],
            Print["! Not a B rule: ", rule];
            Throw[BMapLoad]];
        {k0, v0} = List @@ rule;
        k = name @@ k0;
        v = v0 /. B -> name;
        If[B @@ k === k0,
            Evaluate[k] = v;
            ,
            If[k =!= v,
                Print["! Bad duplicate map for: ", k0];
                Print["! Old value: ", k /. name -> B];
                Print["! New value: ", v0];
                Print["!          = ", v /. name -> B];
                Throw[BMapLoad];
                ,
                ndups++;
            ];
        ];
        ,
        {rule, map}
    ];
    Print["Loaded ", Length[map], " rules (", ndups, " duplicates)"];
]

(* Set one key in a B map. Check for conflicting rules. *)
BMapSet[name_Symbol, key_B, value_] := Module[{k, v},
    k = name @@ key;
    v = value /. B -> name;
    If[B @@ k === key,
        Evaluate[k] = v;
        ,
        If[k =!= v,
            Print["! Bad duplicate map for: ", key];
            Print["! Old value: ", k /. name -> B];
            Print["! New value: ", value];
            Print["!          = ", v /. name -> B];
            Throw[BMapAdd];
        ];
    ];
];

(* Save a B map to a file, as a list of substitution rules. *)
BMapSave[name_Symbol, filename_String] :=
    Put[DownValues[Evaluate[name]] /. name -> B /. (Verbatim[HoldPattern][pat_] :> val_) :> (pat -> val) // Sort, filename]

(* Clear a B map. *)
BMapClear[name_Symbol] := Clear[Evaluate[name]]

(* Apply a B map to an expression. *)
BMapApply[name_Symbol, ex_] := ex /. B -> name /. name -> B
BMapApply[name_Symbol] := BMapApply[name, #] &

BMapAppendTo[result_Symbol, rest__] := Module[{names = List[rest], keys, name, values},
    keys = Prepend[names, result] // Map[(DownValues[#] // Map[First] // ReplaceAll[# -> B] // Map[ReleaseHold])&] // Apply[Join] // Union;
    values = keys /. B -> result /. result -> First[names];
    Do[values = values /. names[[i-1]] -> names[[i]], {i, 2, Length[names]}];
    values = values /. Last[names] -> result;
    Clear[Evaluate[result]];
    DownValues[Evaluate[result]] = MapThread[RuleDelayed, {keys // Map[HoldPattern] // ReplaceAll[B -> result], values}];
]

BMapAppendOne[name_Symbol, key_B, value_] := Module[{keys, values},
    keys = BMapKeys[name] // Append[#, key]&;
    values = keys /. B -> name /. name -> B /. key -> value;
    Clear[Evaluate[name]];
    DownValues[Evaluate[name]] = MapThread[RuleDelayed, {keys // Map[HoldPattern], values}] // ReplaceAll[B -> name];
];

BMapMapValues[name_Symbol, fn_] := Module[{keys, values},
    keys = BMapKeys[name];
    values = keys // BMapApply[name] // Map[fn];
    Clear[Evaluate[name]];
    DownValues[Evaluate[name]] = MapThread[RuleDelayed, {keys // Map[HoldPattern], values}] // ReplaceAll[B -> name];
];

BMapMapItems[name_Symbol, fn_] := Module[{keys, values, kv},
    keys = BMapKeys[name];
    values = keys // BMapApply[name];
    kv = MapThread[fn, {keys, values}];
    Clear[Evaluate[name]];
    DownValues[Evaluate[name]] = Map[RuleDelayed @@ {HoldPattern[Evaluate[#[[1]]]], #[[2]]}&, kv] // ReplaceAll[B -> name];
];

BMapMasters[name_Symbol] := DownValues[Evaluate[name]] /. name -> B // Map[#[[2]]&] // Cases[#, _B, -1]& // Union

BMapLength[name_Symbol] := DownValues[Evaluate[name]] // Length

BMapKeys[name_Symbol] := DownValues[Evaluate[name]] // Map[First] // ReplaceAll[name -> B] // Map[ReleaseHold]

BMapRules[name_Symbol] := DownValues[Evaluate[name]] /. name -> B /. {RuleDelayed -> Rule, Verbatim[HoldPattern][x_] :> x}

(*
 * ## Maple
 *)

(* Set `$MapleBinary` variable or `MAPLE` environment variable
 * before using this. By default `maple` is used. *)
If[Not[MatchQ[$MapleBinary, _String]],
    $MapleBinary = Environment["MAPLE"] /. $Failed -> "maple"];

(* Set `$MapleDebug` to `True` to see Maple input/output. *)
If[Not[MatchQ[$MapleDebug, True|False]],
    $MapleDebug = False];

(* Run a Maple script defined by a (possibly nested) list of
 * expressions. Export the 'result' variable from Maple after
 * the script is over, and return it's value.
 *
 * Note that sometimes when something goes wrong, 'mserver'
 * process lingers on, even after the maple session is over. Those
 * need to be killed manually, for example by 'pkill mserver'.
 *)
MapleRun[script_List] := Module[{fullscript, resultfile, proc, result},
    resultfile = MkTemp["mapleresult", ".mpl"];
    fullscript = {
        script,
        "save(result, ", resultfile // InputForm, "):\n",
        "quit\n"
    };
    logfile = resultfile <> ".log";
    (* RunProcess sometimes hangs, while OpenWrite seems to work fine...
     * You will need to 'pkill mserver' from time to time, as those
     * seem to linger on sometimes.
     *)
    If[$MapleDebug, Print["Maple input: ", MkString[fullscript]]];
    proc = OpenWrite[MkString["!",
        $MapleBinary // InputForm,
        " -qtsc 'interface(historyfile=none,prettyprint=0,screenwidth=80)' 1>",
        logfile // InputForm,
        " 2>&1"
    ], BinaryFormat->True];
    If[MatchQ[proc, $Failed],
        Error["! Failed to run Maple from ", $MapleBinary];
    ];
    WrString[proc, fullscript];
    Close[proc];
    If[$MapleDebug, Print["Maple output: ", ReadString[logfile]]];
    If[$MapleDebug, Print["Maple result: ", ReadString[resultfile]]];
    If[FileExistsQ[resultfile],
        result = MapleGet[resultfile];
        DeleteFile[resultfile];
        DeleteFile[logfile];
        result
        ,
        Print["! Maple script failed to produce a result"];
        If[Not[$MapleDebug],
            Print["Maple input: ", MkString[fullscript]];
            Print["Maple output: ", ReadString[logfile]];
        ];
        DeleteFile[logfile];
        Error["! Maple script failed to produce a result"];
    ]
]

MapleF[fun_String, arg1_] := MapleRun[{
        "xxxarg1 := ", arg1 // ToMaple, ":\n",
        "result := ", fun, "(xxxarg1):\n"
    }]

MapleF[fun_String, arg1_, arg2_] := MapleRun[{
        "xxxarg1 := ", arg1 // ToMaple, ":\n",
        "xxxarg2 := ", arg2 // ToMaple, ":\n",
        "result := ", fun, "(xxxarg1, xxxarg2):\n"
    }]

(* Read a Maple file created by 'save(var, "filename")'. Strip
 * the var name, only return the content.
 *)
MapleGet[filename_String] := Module[{text},
    text = ReadString[filename];
    If[text === $Failed,
        Error["! Failed to read from ", filename];
    ];
    FromMaple[text]
]

FromMaple[text_String] :=
    text //
    (* Drop the final '\' on a line. *)
    StringReplace[RegularExpression["(?m)\\\\$"] -> ""] //
    (* Drop the whitespace. *)
    StringReplace[RegularExpression["\\s"] -> ""] //
    (* Drop the enclosing 'var := ' and ';'. *)
    StringReplace[RegularExpression["^[\\w]+:=|[;:]$"] -> ""] //
    (* Transform simple indices like 'zeta[2]' into function
     * calls like 'zeta(2)'. Note that if index arguments contain
     * '[]', this regex will fail.
     *)
    StringReplace[RegularExpression["(\\w)\\[([^]]+)\\]"] -> "$1($2)"] //
    (* Every other occurrence of '[' and ']' are lists. *)
    StringReplace[{"[" -> "{", "]" -> "}"}] //
    ToExpression[#, TraditionalForm, Hold] & //
    ReplaceAll[O->OO] //
    ReplaceAll[FromMaple$Map] //
    ReleaseHold

FromMaple$Map = {
    HoldPattern[psi[x_]] :> PolyGamma[x],
    HoldPattern[psi[n_, x_]] :> PolyGamma[n, x],
    (* Note that HyperInt uses the original Goncharov notation
     * for Li and MZV, unlike HPL/HypExp, which use the reverse
     * one.
     *)
    (*HoldPattern[zeta[n__]] :> MZV[Reverse[{n}]],*)
    HoldPattern[zeta[n__]] :> Mzv @@ Reverse[{n}],
    HoldPattern[polylog[n_, x_]] :> PolyLog[n, x],
    HoldPattern[Complex[yy_]] :> Complex[0, yy],
    HoldPattern[Complex[xx_, yy_]] :> Complex[xx, yy]
};

(* Save an expression in a format suitable for Maple's 'read()'
 * command.
 *
 * The name of the variable is set automatically to the
 * basename of the file, so 'MaplePut[..., "x.mma"]' would
 * result in a variable 'x' being defined after 'read("x.mma")'
 * is executed.
 *)
MaplePut[expression_, filename_String] :=
    MaplePut[expression, filename, FileBaseName[filename]]

MaplePut[expression_, filename_String, varname_String] := Module[{fd},
    fd = OpenWrite[filename];
    If[fd === $Failed, Error["MaplePut: failed to open ", filename, " for writing"]];
    WrString[fd, varname, " := ", expression // ToMaple, ":\n"];
    Close[fd];
]

(* Convert a Mathematica expression into a a string with an
 * equivalent Maple expression. *)
ToMaple[expression_] :=
    ToString[expression /. ToMaple$Map, InputForm] //
        StringReplace[{" " -> "", "[" -> "(", "]" -> ")", "{" -> "[", "}" -> "]"}]

ToMaple$Map = {
    HoldPattern[Log[x_]] :> ln[x],
    HoldPattern[PolyGamma[x_]] :> psi[x],
    HoldPattern[PolyGamma[n_, x_]] :> psi[n, x],
    HoldPattern[PolyLog[n_, x_]] :> polylog[n, x],
    (* There's no Nielsen polylog on the Maple side; we'll convert
     * it into 'Hpl' from HyperInt.
     *)
    HoldPattern[PolyLog[n_, p_, x_]] :> Hpl[x, Join[Table[0, n], Table[1, p]]],
    (* Convert 'Zeta', 'HPL', 'MZV' and 'Mzv' into HyperInt equivalents.
     *)
    (*HoldPattern[Zeta[n_]] :> zeta[n],*)
    HoldPattern[Zeta[n_]] :> Hpl[1, {n}],
    HoldPattern[HPL[w_List, x_]] :> Hpl[x, w],
    (* Note that HyperInt uses the original Goncharov notation
     * for Li and MZV, unlike HPL/HypExp, which use the reverse
     * one.
     *)
    (* HoldPattern[MZV[n_List]] :> zeta @@ Reverse[n] *)
    HoldPattern[MZV[{w__}]] :> MzvToHpl[Mzv[w]],
    HoldPattern[z_Mzv] :> MzvToHpl[z]
};

(*
 * ## HyperInt
 *)

(* Set `$HyperIntDir` variable or `HYPERINTDIR` environment
 * variable before using. By default the current directory is
 * used. *)
If[Not[MatchQ[$HyperIntDir, _String]],
    $HyperIntDir = Environment["HYPERINTDIR"] /. $Failed -> "."];

ClearAll[HyperIntConvert];
(*HyperIntConvert[expr_?(FreeQ[_Hlog | _HPL | _Hpl | _Log | _MZV | _Mzv | _Mpl | _PolyGamma | _psi | _PolyLog | _polylog | _Zeta | _zeta]), form_] := expr*)
HyperIntConvert[expr_, form_] := MapleRun[{
        "_hyper_autoload_periods := [",
            FileNameJoin[{$HyperIntDir, "periodLookups.m"}] // InputForm,
            (*", ", FileNameJoin[{$HyperIntDir, "periodLookupsAlt9.m"}] // InputForm,*)
            (*", ", FileNameJoin[{$HyperIntDir, "periodLookupsAlt10.m"}] // InputForm,*)
            (*", ", FileNameJoin[{$HyperIntDir, "periodLookupsAlt11.m"}] // InputForm,*)
        "]:\n",
        "read ", FileNameJoin[{$HyperIntDir, "HyperInt.mpl"}] // InputForm, ":\n",
        "xxxexpr := ", expr // ToMaple, ":\n",
        "xxxform := ", form // ToMaple, ":\n",
        "result := convert(xxxexpr, xxxform):\n"
    }]
HyperIntConvert[form_] := HyperIntConvert[#, form]&
HyperIntConvert[expr_List, form_] := Map[HyperIntConvert[form], expr]
HyperIntConvert[expr_Rule, form_] := Map[HyperIntConvert[form], expr]
HyperIntConvert[expr_SeriesData, form_] := MapSeries[HyperIntConvert[form], expr]

ClearAll[HyperIntFibrationBasis];
HyperIntFibrationBasis[expr_?(FreeQ[_Hlog | _HPL | _Hpl | _Log | _MZV | _Mzv | _Mpl | _PolyGamma | _psi | _PolyLog | _polylog | _Zeta | _zeta]), basis_List] := expr
HyperIntFibrationBasis[expr_, basis_List] := (*HyperIntFibrationBasis[expr, basis] =*) MapleRun[{
        "_hyper_autoload_periods := [",
            FileNameJoin[{$HyperIntDir, "periodLookups.m"}] // InputForm,
            ", ", FileNameJoin[{$HyperIntDir, "periodLookupsAlt9.m"}] // InputForm,
            (*", ", FileNameJoin[{$HyperIntDir, "periodLookupsAlt10.m"}] // InputForm,*)
            (*", ", FileNameJoin[{$HyperIntDir, "periodLookupsAlt11.m"}] // InputForm,*)
        "]:\n",
        "read ", FileNameJoin[{$HyperIntDir, "HyperInt.mpl"}]//InputForm, ":\n",
        "xxxexpr := ", expr // ToMaple, ":\n",
        "xxxbasis := ", basis // ToMaple, ":\n",
        (*"result := fibrationBasis(Hlog(1,[1-x]),[x]):\n",
        "rtime := time():\n",*)
        "result := convert(fibrationBasis(xxxexpr, xxxbasis), Hlog):\n"
        (*"rtime := sprintf(\"%.6f\", time()-rtime):\n",
        "save(rtime, ", "/tmp/runtime" // InputForm, "):\n"*)
    }]
HyperIntFibrationBasis[basis_List] := HyperIntFibrationBasis[#, basis]&
HyperIntFibrationBasis[expr_List, basis_List] := Map[HyperIntFibrationBasis[basis], expr]
HyperIntFibrationBasis[expr_Rule, basis_List] := Map[HyperIntFibrationBasis[basis], expr]
HyperIntFibrationBasis[expr_SeriesData, basis_List] := MapSeries[HyperIntFibrationBasis[basis], expr]

ClearAll[HyperInt];
HyperInt[expr_, bounds:({_, _, _} ..)] := HyperInt[expr, bounds] = MapleRun[{
        "_hyper_autoload_periods := [",
            FileNameJoin[{$HyperIntDir, "periodLookups.m"}] // InputForm,
            ", ",
            FileNameJoin[{$HyperIntDir, "periodLookupsAlt10.m"}] // InputForm,
        "]:\n",
        "read ", FileNameJoin[{$HyperIntDir, "HyperInt.mpl"}]//InputForm, ":\n",
        "xxxexpr := ", expr // ToMaple, ":\n",
        "result := fibrationBasis(",
            Fold[{"hyperInt(", #1, ",", #2[[1]]//ToMaple, "=(", #2[[2]]//ToMaple, ")..(", #2[[3]]//ToMaple, "))"}&, "xxxexpr", {bounds}],
        "):\n"
    }]
HyperInt[expr_List, bounds__] := Map[HyperInt[#, bounds]&, expr]
HyperInt[expr_Rule, bounds__] := Map[HyperInt[#, bounds]&, expr]
HyperInt[expr_SeriesData, bounds__] := MapSeries[HyperInt[#, bounds]&, expr]

(* ## Formatting
 *)

(* Prettify Mzv[...] as \[Zeta]. *)
MakeBoxes[Mzv[idx__], form:(StandardForm|TraditionalForm)] :=
    SubscriptBox["\[Zeta]", RowBox[Riffle[Map[MakeBoxes[#, form] &, {idx}], ","]]]

(* Recognize \[Zeta] as Mzv[...]. *)
MakeExpression[SubscriptBox["\[Zeta]", RowBox[idx_List]], StandardForm] :=
    MakeExpression[RowBox[{"Mzv", "[", idx, "]"}], StandardForm]

(* Prettify Hlog[...]. *)
MakeBoxes[Hlog[x_, w_List], TraditionalForm] :=
    RowBox[{
        "G", "(",
        RowBox[Riffle[Map[MakeBoxes[#, TraditionalForm] &, w], ","]], ";",
        MakeBoxes[x, TraditionalForm],
        ")"
    }]

(* Prettify Hpl[...]. *)
MakeBoxes[Hpl[x_, w_List], TraditionalForm] :=
    RowBox[{
        SubscriptBox["H", RowBox[Riffle[Map[MakeBoxes[#, TraditionalForm] &, w], ","]]],
        "(",
        MakeBoxes[x, TraditionalForm],
        ")"
    }]

(* ## Hlog
 *)

HlogInfinitePattern = Hlog[0, {0 ..}] | Hlog[x:Except[0], {x_, ___}]
HlogZeroPattern = Hlog[0, Except[{0 ..}, _List]] | Hlog[1, {0 ..}]

GToHlog[ex_] := ex /. G[idx__, x_] :> Hlog[x, {idx}]
HlogToG[ex_] := ex /. Hlog[x_, idx_List] :> G[Sequence@@idx, x]

MaxZetaWeight[ex_List] := Map[MaxZetaWeight, ex]
MaxZetaWeight[ex_SeriesData] := Max[Map[MaxZetaWeight, ex[[3]]]]
MaxZetaWeight[ex_Plus] := ex // Apply[List] // Map[MaxZetaWeight] // Max
MaxZetaWeight[ex_Times] := ex // Apply[List] // Map[MaxZetaWeight] // Apply[Plus]
MaxZetaWeight[ex_^n_] := MaxZetaWeight[ex]*n
MaxZetaWeight[Mzv[w__]] := Plus@@Abs[{w}]
MaxZetaWeight[Zeta[w_]] := w
MaxZetaWeight[Pi] := 1
MaxZetaWeight[Log[2]] := 1
MaxZetaWeight[G[idx__, x_]] := Length[{idx}]
MaxZetaWeight[Hlog[x_, w_List]] := Length[w]
MaxZetaWeight[Hpl[x_, w_List]] := Plus@@Abs[w]
MaxZetaWeight[HPL[w_List, x_]] := Plus@@Abs[w]
MaxZetaWeight[ex_] := 0

SeriesMapFilter[f_] := SeriesMapFilter[#, f]&
SeriesMapFilter[ex_SeriesData, f_] := Module[{ord, result, keeptail, val, done, term},
  result = {};
  keeptail = True;
  Do[
    {val, done} = f[term];
    result = {result, val};
    If[done, keeptail = False; Break[]];
    ,
    {term, ex[[3]]}];
  result = Flatten[result];
  SeriesData[ex[[1]], ex[[2]], result, ex[[4]], If[keeptail, ex[[5]], ex[[4]] + Length[result]], ex[[6]]]
]

SeriesDropZetaWeight[ex_SeriesData, n_Integer] := Module[{badord},
  badord = ex[[3]] // MapIndexed[If[MaxZetaWeight[#1] >= n, #2[[1]], Nothing] &] // Min[#, Length[ex[[3]]] + 1] &;
  SeriesData[ex[[1]], ex[[2]], ex[[3, ;; badord - 1]], ex[[4]], ex[[5]] - Length[ex[[3]]] + badord - 1, ex[[6]]]
]
SeriesDropZetaWeight[ex_List, n_Integer] := Map[SeriesDropZetaWeight[#, n] &, ex]
SeriesDropZetaWeight[n_] := SeriesDropZetaWeight[#, n] &

SufficientlyLongSeries[ex_, var_, minterms_] := Module[{k, series, mintermcount},
  For[k = 0, k < minterms + 1000, k++,
    series = Series[ex, {var, 0, k}];
    mintermcount = series // CaseUnion[s_SeriesData :> SeriesTermCount[s]] // Min;
    If[mintermcount === Infinity,
      Print["Not expanding: it's a constant in ", var];
      series = ex(* + O[var]^(minterms + 1000)*);
      Break[];
    ];
    Print["If ex is expanded to ", x, "^", k, " -> at least ", mintermcount, " terms everywhere"];
    If[mintermcount > minterms, Print["Enough expanding at ", var, "^", k]; Break[]];
    If[mintermcount > 0,
      k = k + minterms - mintermcount;
      Continue[];
    ];
  ];
  series
]

HlogCollect[ex_List] := Map[HlogCollect, ex]
HlogCollect[ex_SeriesData] := MapAt[HlogCollect, ex, 3]
HlogCollect[ex_] := Bracket[ex, _Hlog, Together]

ClearAll[Hlog, HlogInt, HlogIntTerm];

HlogFromLogs[ex_] := ex /. {Log[x_]^n_. :> Factorial[n] Hlog[x, Table[0, n]]}

Hlog[_, {}] = 1

Derivative[1, {0 ..}][Hlog][x_, {w1_, wrest___}] := Hlog[x, {wrest}]/(x - w1)

Derivative[0, dw : {(0|1) ..} /; (Plus @@ dw) == 1][Hlog][x_, w_List] := Module[{W, DW},
    DW = Table[W[i], {i, Length[w]}]*dw // Apply[Plus];
    Sum[Hlog[x, Drop[w, {i}]] D[Log[(W[i - 1] - W[i])/(W[i] - W[i + 1])], DW], {i, Length[w]}] /.
        {W[0] -> x, W[Length[w] + 1] -> 0, W[i_] :> w[[i]]}
    ]

ClearAll[HlogD];
(* This convoluted procedure is needed to get HlogD[Hlog[x, {y, y}], y] right.
 * When done naively, 1/(a[i] - a[i+1]) factors explode.
 *)
HlogD[h:Hlog[arg_, w_List], x_] := HlogD[h, x] = Module[{a, DD, aval},
    aval = Join[{arg}, w, {0}];
    Sum[Hlog[arg, Drop[w, {i}]] Log[(a[i - 1] - a[i])/(a[i] - a[i + 1])], {i, Length[w]}] //
        Collect[#, _Hlog, (# // Together // Sum[D[#, a[i]] D[aval[[i+1]], x], {i, 0, Length[w]+1}]& // Together // ReplaceAll[a[i_] :> aval[[i+1]]])&]&
]
HlogD[ex_List, x_] := Map[HlogD[x], ex]
HlogD[ex_Plus, x_] := Map[HlogD[x], ex]
HlogD[ex_Times, x_] := HlogD[ex, x] = Sum[Drop[ex, {i}] * HlogD[ex[[i]], x], {i, Length[ex]}]
HlogD[Verbatim[SeriesData][v_, v0_, s_List, n1_, n2_, d_], x_] := SeriesData[v, v0, HlogD[s, x], n1, n2, d]
HlogD[(ex_)^n_, x_] := n*(ex)^(n-1)*HlogD[ex, x]
HlogD[ex_?(FreeQ[#, _Hlog]&), x_] := D[ex, x]
HlogD[ex_, x_] := Error["Failed to Hlog-differentiate expression: ", ex, " over variable ", x]
HlogD[x_] := HlogD[#, x]&

HlogInt[ex_, {x_, x1_, x2_}] := HlogInt[ex, x] // (# /. x -> x2) - (# /. x -> x1) &
HlogInt[x_] := HlogInt[#, x]&
HlogInt[l_List, x_] := Map[HlogInt[#, x]&, l]
HlogInt[Verbatim[SeriesData][v_, v0_, s_List, n1_, n2_, d_], x_] := SeriesData[v, v0, HlogInt[s, x], n1, n2, d]

HlogInt[ex_, x_] := Module[{terms, a, b, k},
    terms = ex // Expand // Terms;
    terms = terms // Apart[#, x]&;
    terms = terms // Terms[Plus @@ #]&;
    terms = terms /. (a_. x + b_.)^(k_?Negative) :> (HlogSymbol[-b/a, x]/a)^(-k) /; FreeQ[a,x] && FreeQ[b,x];
    Plus @@ Map[(
        (* Separate parts dependent on 'x' and free from it *)
        k = Times @@@ GroupBy[Power @@@ FactorList[#], FreeQ[x]];
        k[True] HlogIntTerm[Replace[k[False], _Missing -> 1], x]
    )&, terms]
]

HlogIntTerm[f_?(FreeQ[HlogSymbol | Hlog]), x_] := Integrate[f, x]

HlogIntTerm[HlogSymbol[a_, x_], x_] :=
    Hlog[x, {a}]
HlogIntTerm[HlogSymbol[a_, x_]^k_, x_] :=
    Integrate[1/(x-a)^k, x]
HlogIntTerm[x_^k_?Positive HlogSymbol[a_, x_], x_] :=
    x^k/k + a HlogIntTerm[x^(k-1)HlogSymbol[a, x], x]
HlogIntTerm[x_ HlogSymbol[a_, x_], x_] :=
    x^1/1 + a HlogIntTerm[x^(1-1)HlogSymbol[a, x], x]

HlogIntTerm[HlogSymbol[a_, x_] Hlog[x_, {b__}], x_] :=
    Hlog[x, {a, b}]
HlogIntTerm[HlogSymbol[a_, x_]^k_ Hlog[x_, {b_, brest___}], x_] :=
    -1/(k-1) 1/(x-a)^(k-1) Hlog[x, {b, brest}] + 1/(k-1) HlogInt[1/(x-a)^(k-1) 1/(x-b) Hlog[x, {brest}], x]
HlogIntTerm[x_^k_?Positive HlogSymbol[a_, x_] Hlog[x_, b_], x_] :=
    HlogIntTerm[x^(k-1) Hlog[x, b], x] + a HlogIntTerm[x^(k-1) HlogSymbol[a, x] Hlog[x, b], x]
HlogIntTerm[x_ HlogSymbol[a_, x_] Hlog[x_, b_], x_] :=
    HlogIntTerm[x^(1-1) Hlog[x, b], x] + a HlogIntTerm[x^(1-1) HlogSymbol[a, x] Hlog[x, b], x]

HlogIntTerm[Hlog[x_, {a_, b___}], x_] :=
    (x - a) Hlog[x, {a, b}] - HlogInt[Hlog[x, {b}], x]
HlogIntTerm[x_^k_?Positive Hlog[x_, {a_, b___}], x_] :=
    1/(k+1) x^(k+1) Hlog[x, {a, b}] - 1/(k+1) HlogIntTerm[x^(k+1) HlogSymbol[a, x] Hlog[x, {b}], x]
HlogIntTerm[x_ Hlog[x_, {a_, b___}], x_] :=
    1/(1+1) x^(1+1) Hlog[x, {a, b}] - 1/(1+1) HlogIntTerm[x^(1+1) HlogSymbol[a, x] Hlog[x, {b}], x]

HlogIntTerm[term_, x_] := Error["Failed to Hlog-integrate term: ", term, " over variable ", x]

(* Memoize HlogIntTerm *)
DownValues[HlogIntTerm0] = DownValues[HlogIntTerm] /. HlogIntTerm -> HlogIntTerm0;
ClearAll[HlogIntTerm];
HlogIntTerm[term_, x_] := HlogIntTerm[term, x] = HlogIntTerm0[term, x]

(* Rewrite Hlog[a-x, {...}] as a sum of Hlog[x, {...}] and Hlog[a, {...}] *)
(*
ClearAll[HlogSimplifyArgument]
HlogSimplifyArgument[Hlog[a_ - x_Symbol, {0}], x_Symbol] := Hlog[x, {a}] + Hlog[a, {0}]
HlogSimplifyArgument[Hlog[a_ - x_Symbol, {a_}], x_Symbol] := Hlog[x, {0}] - Hlog[a, {0}]
HlogSimplifyArgument[Hlog[a_ - x_Symbol, {w_}], x_Symbol] := Hlog[x, {a - w}] + Hlog[a, {w}]
HlogSimplifyArgument[Hlog[a_ - x_Symbol, {a_, wrest__}], x_Symbol] := Module[{t},
  HlogInt[ 1/t HlogSimplifyArgument[Hlog[a - t, {wrest}], t], {t, a, x}]
]
HlogSimplifyArgument[Hlog[a_ - x_Symbol, {w_, wrest__}], x_Symbol] := Module[{t},
  Hlog[a, {w, wrest}] + HlogInt[1/(t - a + w) HlogSimplifyArgument[ Hlog[a - t, {wrest}], t], {t, 0, x}]
]
HlogSimplifyArgument[h_Hlog, x_Symbol] := h
HlogSimplifyArgument[ex_, x_Symbol] := ex /. h_Hlog :> HlogSimplifyArgument[h, x]
HlogSimplifyArgument[x_Symbol] := HlogSimplifyArgument[#, x] &
*)
ClearAll[HlogArgTransform];
(* x -> a-x *)
HlogArgTransform[Hlog[x_, {0}], A - X, a_] := Hlog[a - x, {a}] + Hlog[a, {0}]
HlogArgTransform[Hlog[x_, {a_}], A - X, a_] := Hlog[a - x, {0}] - Hlog[a, {0}]
HlogArgTransform[Hlog[x_, {w_}], A - X, a_] := Hlog[a - x, {a - w}] + Hlog[a, {w}]
HlogArgTransform[Hlog[x_, {a_, ww__}], A - X, a_] := Module[{t},
  HlogInt[1/t HlogArgTransform[Hlog[a - t, {ww}], A - X, a], {t, a, a - x}]
]
HlogArgTransform[Hlog[x_, {w_, ww__}], A - X, a_] := Module[{t},
  Hlog[a, {w, ww}] + HlogInt[1/(t - a + w) HlogArgTransform[Hlog[a - t, {ww}], A - X, a], {t, 0, a - x}]
]
(* x -> -x *)
HlogArgTransform[Hlog[x_, w:{___, Except[0]}], -X] := Hlog[-x, -w]
(* The rest *)
HlogArgTransform[h_Hlog, __] := h
HlogArgTransform[ex_, args__] := ex /. h_Hlog :> HlogArgTransform[h, args]

(* ## Hlog Shuffle Algebra
 *)

ClearAll[AllMerges];
AllMerges[n1_Integer, n2_Integer] := AllMerges[n1, n2] = Module[{i1, i2},
    Permutations[Join[Table[1, n1], Table[2, n2]]] // Map[(
        i1 = i2 = 1;
        Table[If[pi === 1, i1++, n1 + i2++], {pi, #}]
    )&]
]
AllMerges[l1_List, l2_List] := Module[{l12 = Join[l1, l2]}, AllMerges[Length[l1], Length[l2]] // Map[Part[l12, #]&]]

HlogProductExpand[ex_SeriesData] := If[ex[[3]] === {}, ex, MapAt[HlogProductExpand, ex, {3, ;;}]]
HlogProductExpand[ex_List] := Map[HlogProductExpand, ex]
HlogProductExpand[ex_] := FixedPoint[(Expand[#, _Hlog]&) /* ReplaceAll[{
        Hlog[x_, w1_List] Hlog[x_, w2_List] :> (AllMerges[w1, w2] // Map[Hlog[x, #]&] // Apply[Plus]),
        Hlog[x_, {w_}]^n_?Positive :> n! Hlog[x, Table[w, n]],
        Hlog[x_, w_List]^n_?EvenQ :> (AllMerges[w, w] // Map[Hlog[x, #]&] // Apply[Plus])^(n/2),
        Hlog[x_, w_List]^n_?OddQ :> Hlog[x, w] (AllMerges[w, w] // Map[Hlog[x, #]&] // Apply[Plus])^((n-1)/2)
    }], ex]

GProductExpand[ex_] := ex // GToHlog // HlogProductExpand // HlogToG

HlogExtractTrail[ex_, pat_] := ex // HlogExtractTrail[pat]
HlogExtractTrail[pat_] := Module[{i},
  ReplaceAll[
    Hlog[x_, {u___, w:Except[pat], a : Longest[pat ..]}] :> Sum[
      (-1)^i (AllMerges[{u}, Take[{a}, i] // Reverse] //
            Map[Append[w]] // Map[Hlog[x, #]*Hlog[x, Drop[{a}, i]] &] //
           Flatten // Apply[Plus]),
      {i, 0, Length[{a}]}]
    ]
]

HlogExtractLead[ex_, pat_] := ex // HlogExtractLead[pat]
HlogExtractLead[pat_] := ReplaceAll[
  Hlog[x_, {a : Longest[pat ..], w:Except[pat], u___}] :> Sum[
    (-1)^i (AllMerges[Take[Reverse[{a}], i], {u}] // Map[Prepend[w]] //
          Map[Hlog[x, #]*Hlog[x, Reverse[Drop[Reverse[{a}], i]]] &] //
         Flatten // Apply[Plus]),
    {i, 0, Length[{a}]}]
  ]

ClearAll[HlogExtractLogs];

HlogExtractLogs[h : Hlog[x_, w : {0 ..}]] := Hlog[x, {0}]^Length[w]/Factorial[Length[w]]

HlogExtractLogs[h : Hlog[_, {___, _?(# =!= 0 &)}]] := h

HlogExtractLogs[h : Hlog[x_, {w___, z : (0 ..)}]] :=
    Hlog[x, {w}] Hlog[x, {0}]^Length[{z}]/Factorial[Length[{z}]] - (AllMerges[{w}, {z}][[2 ;;]] // Map[HlogExtractLogs[Hlog[x, #]] &] // Apply[Plus])

HlogExtractLogs[ex_] := ex /. h_Hlog :> HlogExtractLogs[h]

ClearAll[HlogExtractInfinite];

HlogExtractInfinite[h : Hlog[x_, w : {x_ ..}]] := Hlog[x, {x}]^Length[w]/Factorial[Length[w]]

HlogExtractInfinite[h : Hlog[x_, {y_, ___}] /; x =!= y] := h

HlogExtractInfinite[h : Hlog[x_, {w1 : Longest[x_ ..], w2___}]] :=
    Hlog[x, {w2}] Hlog[x, {x}]^Length[{w1}]/Factorial[Length[{w1}]] - (AllMerges[{w1}, {w2}][[2 ;;]] // Map[HlogExtractInfinite[Hlog[x, #]] &] // Apply[Plus])

HlogExtractInfinite[ex_] := ex /. h_Hlog :> HlogExtractInfinite[h]

(* ## Hlog series expansion
 *)

(* Hlog <-> Gi *)
HlogToGi[h:Hlog[_, {0 ..}]] := h
HlogToGi[h:Hlog[_, {___, Except[0], 0 ..}]] := HlogExtractTrail[h, 0] // HlogToGi
HlogToGi[Hlog[x_, w_List]] := Module[{wi, nzeros = 0},
    Table[If[wi === 0, nzeros++; Nothing, {nzeros+1, nzeros=0; wi}], {wi, w}] // Gi[Sequence @@ Transpose[#], x]&
]
HlogToGi[ex_] := ex /. h_Hlog :> HlogToGi[h]
GiToHlog[Gi[m_List, w_List, x_]] := Hlog[x, MapThread[{Table[0, #1 - 1], #2}&, {m, w}] // Flatten]
GiToHlog[ex_] := ex /. g_Gi :> GiToHlog[g]

(* Hlog expansion *)
HlogSeries[ex_, order_] := ex // HlogExtractTrail[0]//ReplaceAll[Hlog[x,z:{0 ..}]:>Log[x]^Length[z]/Length[z]!] // HlogToGi // GiSeries[#, order]&
HlogSeries[order_] := HlogSeries[#, order]&
GiSeries[Gi[ms_List, xs_List, x_], order_] := Module[{k = ms // Length},
    Range[k, order]
    // Map[IntegerPartitions[#, {k}]&] // Apply[Join]
    // Map[Permutations] // Apply[Join]
    // Map[Times[
            Power[x / xs, #],
            Power[Reverse @ Rest @ FoldList[Plus, 0, # // Reverse], -ms]
        ]&
    ] // Apply[Times, #, 2]& // Apply[Plus] // (-1)^k # + O[x]^(order + 1)&
]
GiSeries[ex_, order_] := ex /. g_Gi :> GiSeries[g, order]

(* ## Hpl
 *)

HplFromLogs[ex_, x_] := ex /. {
    Log[x]^n_. :> Factorial[n] Hpl[x, Table[0, n]],
    Log[1-x]^n_. :> (-1)^n Factorial[n] Hpl[x, Table[1, n]],
    Log[1+x]^n_. :> Factorial[n] Hpl[x, Table[-1, n]]
}
HplFromLogs[x] := HplFromLogs[#, x]&

HPLFromLogs[ex_, x_] := HplFromLogs[ex, x] // HplToHPL
HPLFromLogs[x] := HPLFromLogs[#, x]&

Hpl[_, {}] := 1

Derivative[1, {0 ..}][Hpl][x_, {1, a___}] := 1/(1 - x) Hpl[x, {a}]
Derivative[1, {0 ..}][Hpl][x_, {0, a___}] := 1/x Hpl[x, {a}]
Derivative[1, {0 ..}][Hpl][x_, {-1, a___}] := 1/(1 + x) Hpl[x, {a}]

HplInt[ex_, x_] := HlogInt[ex // HplToHlog, x] // HlogToHpl
HplInt[x_] := HplInt[#, x]&

HlogToHpl[ex_] := ex /. {
    Hlog[x_, w:{(0|1|-1)..}] :> (-1)^Count[w, 1] Hpl[x, HplAToM[w]],
    h_Hlog :> Error["Can't convert to Hpl: ", h]
}

HplToHlog[ex_] := Module[{a},
    ex /. {
        Hpl[x_, w_List] :> (a = HplMToA[w]; (-1)^Count[a, 1] Hlog[x, a]),
        h_Hpl :> Error["Can't convert to Hlog: ", h]
    }
]

HplMToA[m_List] := HplMToA[m] = (m // Map[Switch[#,
        _Integer?Positive, {Table[0, # - 1], 1},
        _Integer?Negative, {Table[0, -# - 1], -1},
        0, 0,
        _, Error["HplMToA: Not a valid Hpl weight list: ", m]
    ]&] // Flatten)

HplAToM[a_List] := HplAToM[a] = Module[{nzero = 0, w, m},
    m = Table[Switch[i,
        _Integer?Positive, w = i + nzero; nzero = 0; w,
        _Integer?Negative, w = i - nzero; nzero = 0; w,
        0, nzero++; Nothing,
        _, Error["HplAToM: Not a valid Hpl weight list: ", a]
    ], {i, a}];
    Join[m, Table[0, nzero]]
]

HplToHPL[ex_] := ex /. Hpl[x_, w_List] :> HPL[w, x]
HPLToHpl[ex_] := ex /. HPL[w_List, x_] :> Hpl[x, w]

(* ## Mzv
 *)

Hpl1ExtractTrail0[ex_] := ex /. Hpl[1, {0 ..}] -> 0 /. Hpl[1, {w__, a:Longest[0 ..]}] :>
    (HplMToA[{w}] // (-1)^Length[{a}] (AllMerges[#[[;;-2]], {a} // Reverse] // Map[Append[#[[-1]]]] // Map[Hpl[1, HplAToM[#]]&] // Apply[Plus])&)

Assert[Hpl[1, {0, 0, 0, 2, 0, 0, 0}] // Hpl1ExtractTrail0 // # === -35 Hpl[1, {8}]&];

ClearAll[HplToMzv];
HplToMzv[Hpl[1, {0 ..}]] := 0
HplToMzv[Hpl[1, {m_?Positive}]] := Mzv[m]
HplToMzv[Hpl[1, {m_?Negative}]] := -Mzv[m]
HplToMzv[Hpl[1, {w__, a:Longest[0 ..]}]] :=
    HplMToA[{w}] // (-1)^Length[{a}] (AllMerges[#[[;;-2]], {a} // Reverse] // Map[Append[#[[-1]]]] // Map[HplToMzv[Hpl[1, HplAToM[#]]]&] // Flatten // Apply[Plus])&
HplToMzv[Hpl[1, w_List]] := HplAToM[w] // (-1)^Count[#, _?Negative] Mzv[#[[1]], #[[2;;]]*Map[If[Negative[#], -1, 1]&, #[[;;-2]]]//Apply[Sequence]] &
HplToMzv[ex_] := ex /. h:Hpl[1, _List] :> HplToMzv[h]

Assert[Hpl[1, {0, 0, 0, 2, 0, 0, 0}] // HplToMzv // # === -35 Mzv[8]&];

HlogToMzv[ex_] := ex /. Hlog[1, w:{(0|1|-1) ..}] :> (-1)^(Count[w, 1]) HplToMzv[Hpl[1, HplAToM[w]]]

ToMzv[ex_] := ex /.
    HPLs8a -> Mzv[8] + Mzv[5, 3] /.
    Pi^n_?EvenQ :> (6 Mzv[2])^(n/2) /.
    Pi^n_?OddQ :> Pi (6 Mzv[2])^((n-1)/2) /.
    Zeta[w_] :> Mzv[w] /.
    MZV[w_List] :> Mzv @@ w // HlogToMzv // HplToMzv

MzvToHpl[ex_] := ex /. Mzv[ww__] :> Module[{w, s = 1, os = 1},
    w = Table[If[Negative[w], s = -s; os = s*os; -s*w, os = s*os; s*w], {w, {ww}}];
    os*Hpl[1, w]
]

LoadMzvTable[filename_String] := Module[{},
  If[FileExistsQ[filename <> ".mx"],
      Print["Reading ", filename, ".mx"];
      SafeGet[filename <> ".mx"];
      ,
      ClearAll[H1];
      SafeGet[filename];
      H1[0 ..] = 0;
      H1[w__, 0] := Hlog[1, HplMToA[{w, 0}]] // HlogExtractTrail[0] // ReplaceAll[Hlog[1, ww_] :> H1 @@ HplAToM[ww]];
      DumpSave[filename <> ".mx", H1];
  ];
]
ReduceMzv[ex_] := ex // ToMzv // MzvToHpl // ReplaceAll[Hpl[1, w_List] :> H1 @@ w] // ReplaceAll[H1[w__] :> Hpl[1, {w}]] // ToMzv


(* ## 2dHPL
 *)

ClearAll[Hpl2dToHlog];
Hpl2dToHlog[ex_] := ex /. {
    Hpl2d[x_, w:{(0 | 1 | 1-z_Symbol | z_Symbol) ..}] :> ((-1)^Count[w, 1 | 1-zz_Symbol] Hlog[x, w // Map[Replace[zz_Symbol -> -zz]]]),
    h_Hpl2d :> Error["Can't convert to Hlog: ", h]
}

(* ## Tests
 *)

(*On[Assert]*)

Assert[Module[{e = y + x y + 1/x/(x - a)/(x + 1) + Hlog[x, {1, y, 3}]/x},
    FullSimplify[D[HlogInt[e, x], x] - e] === 0]]

Assert[Module[{e = 10 Hlog[x, {a, b, c}]},
    FullSimplify[D[HlogInt[e, x], x] - e] === 0]]

Assert[Module[{e = y x^3/(x-b) + w x / (x-c) + z x^3/(x-d) Hlog[x, {e, f}]},
    FullSimplify[D[HlogInt[e, x], x] - e] === 0]]

Assert[Module[{e = y x^3 Hlog[x, {a}]},
    FullSimplify[D[HlogInt[e, x], x] - e] === 0]]

Assert[Module[{e = y x^2 Hlog[x, {a, b, c}]},
    FullSimplify[D[HlogInt[e, x], x] - e] === 0]]

Assert[Module[{e = (x^3 + 1)/(x - 1) Hlog[x, {a, b}]},
    FullSimplify[D[HlogInt[e, x], x] - e] === 0]]

end;

(*
 * Graph construction from propagators
 *)

(* FindFundamentalCycles is buggy; it finds different number of
 * cycles for identical graphs:
 *
 *  In[]:= Graph[{0 <-> 1, 2 <-> 3, 2 <-> 3, 2 <-> 3, 2 <-> 3, 1 <-> 3, 1 <-> 3, 2 <-> 9}] // FindFundamentalCycles // Length
 *  Out[]= 1
 *
 *  In[]:= Graph[{0 <-> 1, 1 <-> 3, 2 <-> 3, 2 <-> 3, 2 <-> 3, 2 <-> 3, 1 <-> 3, 2 <-> 9}] // FindFundamentalCycles // Length
 *  Out[]= 4
 *
 * This is a workaround.
 *)
GraphCycleCount[g_] := Module[{edges, uniqueedges},
  edges = EdgeList[g] // ReplaceAll[UndirectedEdge[a_, b_] :> UndirectedEdge @@ Sort[{a, b}]] // Sort;
  uniqueedges = edges // Union;
  Graph[uniqueedges] // FindFundamentalCycles // Length // # + Length[edges] - Length[uniqueedges] &
]

FindVertices[incoming_List, outgoing_List, internal_List] := Module[{vars, terms, tags, cycles, n, VERT, Build, res, maxcoupling},
    vars = Variables[{incoming, outgoing, internal}];
    terms = Table[Coefficient[e, v], {e, Join[incoming, -outgoing, internal, -internal]}, {v, vars}];
    tags = Join[
        MapIndexed[Incoming[#2[[1]], #1] &, incoming],
        MapIndexed[Outgoing[#2[[1]], -#1] &, outgoing],
        MapIndexed[Internal[#2[[1]], #1] &, internal],
        MapIndexed[Internal[#2[[1]], -#1] &, internal]
    ];
    nterms = Length[terms];
    cycles = Length[vars] - Length[incoming] - Length[outgoing] + 1;
    free = Table[True, nterms];
    Build[maxcoupling_, idx_, vertices_] := (
        If[idx === nterms + 1, Return[Sow[vertices // Flatten]]];
        If[Not[free[[idx]]], Return[Build[maxcoupling, idx + 1, vertices]]];
        Range[idx + 1, nterms] //
            Select[free[[#]] &] //
            Subsets[#, {1, maxcoupling - 1}] & //
            Map[Prepend[#, idx] &] //
            Select[MatchQ[Plus @@ terms[[#]], {0..}] &] //
            Map[(
                free[[#]] = False;
                Build[maxcoupling, idx + 1, {vertices, VERT @@ #}];
                free[[#]] = True;
            )&]
    );
    Do[
        res = Reap[Build[maxcoupling, 1, {}]][[2]];
        If[Length[res] === 0, Continue[]];
        res = First[res] /. VERT[idx__] :> tags[[{idx}]];
        res = Select[res, (VerticesToGraph[incoming, outgoing, internal, #] // (ConnectedGraphQ[#] && (GraphCycleCount[#] <= cycles) &)) &];
        If[Length[res] === 0, Continue[]];
        Break[];
        ,
        {maxcoupling, 2, nterms}];
   res // Union
]

VerticesToGraph[incoming_List, outgoing_List, internal_List, v_List] := Graph[Join[
    Table[UndirectedEdge @@ Join[{II[i]}, FirstPosition[v, {___, Incoming[i, _], ___}]], {i, Length[incoming]}],
    Table[UndirectedEdge @@ Join[FirstPosition[ v, {___, Outgoing[i, _], ___}], {OO[i]}], {i, Length[outgoing]}],
    Table[UndirectedEdge @@ Join[
            FirstPosition[v, {___, Internal[i, internal[[i]]], ___}],
            FirstPosition[v, {___, Internal[i, -internal[[i]]], ___}]
        ], {i, Length[internal]}]
]]

ClearAll[VerticesToPrettyGraph, FindGraph, FindGraphs];

VerticesToPrettyGraph[incoming_List, outgoing_List, internal_List, v_List, edgefn_] := Module[{edges1, edges2, edges3, VertexID},
    VertexID[edge_] := FirstPosition[v, {___, edge, ___}, -1, {1}] // First;
    edges1 = incoming // Length // Range // Map[UndirectedEdge[II[#], VertexID[Incoming[#, _]]]&] // MapThread[edgefn[#1, Incoming[#2]]&, {#, incoming}]&;
    edges2 = internal // Length // Range // Map[UndirectedEdge[VertexID[Internal[#, -internal[[#]]]], VertexID[Internal[#, internal[[#]]]]]&] // MapThread[edgefn[#1, Internal[#2]]&, {#, internal}]&;
    edges3 = outgoing // Length // Range // Map[UndirectedEdge[VertexID[Outgoing[#, _]], OO[#]]&] // MapThread[edgefn[#1, Outgoing[#2]]&, {#, outgoing}]&;
    (*
    edges1 = Table[Style[UndirectedEdge @@ Join[{II[i]}, FirstPosition[v, {___, Incoming[i, _], ___}]], Thick, Incoming], {i, Length[incoming]}];
    edges2 = Table[Labeled[Style[UndirectedEdge @@ Join[FirstPosition[v, {___, Outgoing[i, _], ___}], {OO[i]}], Black], Style[outgoing[[i]], Bold]], {i, Length[outgoing]}];
    edges3 = Table[Labeled[Style[UndirectedEdge @@ Join[
                FirstPosition[v, {___, Internal[i, internal[[i]]], ___}],
                FirstPosition[v, {___, Internal[i, -internal[[i]]], ___}]
            ], Thick], internal[[i]]], {i, Length[internal]}];
            *)
    Graph[
        Join[edges1, edges2, edges3],
        VertexShape -> {_II | _OO -> Graphics[]},
        VertexSize -> {_?NumberQ -> 0.1},
        VertexStyle -> {_?NumberQ -> {Black}},
        GraphLayout -> "SpringEmbedding"
    ]
]

DefaultEdgeFn[edge_, id_] := Style[edge, id /. {
    _Internal -> Thick,
    _Incoming -> Gray,
    _Outgoing -> Red
}];

LabeledEdgeFn[edge_, id_] := Labeled[Style[edge, id /. {
       _Internal -> Thick,
       _Incoming -> Gray,
       _Outgoing -> Red
   }], id[[1]] // ToString
];

Options[FindGraphs] = {EdgeFn -> DefaultEdgeFn}
FindGraphs[incoming_List, outgoing_List, internal_List, OptionsPattern[]] :=
    FindVertices[incoming, outgoing, internal] // Map[VerticesToPrettyGraph[incoming, outgoing, internal, #, OptionValue[EdgeFn]]&]

Options[FindGraph] = {EdgeFn -> DefaultEdgeFn}
FindGraph[incoming_List, outgoing_List, internal_List, OptionsPattern[]] :=
    FindVertices[incoming, outgoing, internal] // First // VerticesToPrettyGraph[incoming, outgoing, internal, #, OptionValue[EdgeFn]]&

(* ## HypExp helpers
 *)

ClearAll[MemoizedHypExp];
MemoizedHypExp[h : Verbatim[Hypergeometric2F1][_, _, _, TheX], eps_, n_] := MemoizedHypExp[h, eps, n] = (HypExp[h, eps, n] + O[eps]^(n + 1))
MemoizedHypExp[h : Verbatim[Hypergeometric2F1][a_, b_, c_, x_], eps_, n_] := MemoizedHypExp[Hypergeometric2F1[a, b, c, TheX], eps, n] /.  TheX -> Together[x]
MemoizedHypExp[h : Verbatim[HypergeometricPFQ][_, _, TheX], eps_, n_] := MemoizedHypExp[h, eps, n] = (HypExp[h, eps, n] + O[eps]^(n + 1))
MemoizedHypExp[h : Verbatim[HypergeometricPFQ][p_, q_, x_], eps_, n_] := MemoizedHypExp[HypergeometricPFQ[p, q, TheX], eps, n] /.  TheX -> Together[x]
MemoizedHypExp[ex_, eps_, n_] := ex /. h:(_Hypergeometric2F1|_HypergeometricPFQ) :> MemoizedHypExp[h, eps, n]
MemoizedHypExp[eps_, n_] := MemoizedHypExp[#, eps, n]&

(* ## Feynman Parametrization
 *)

(* Parameterize an integral. Return `{prefactor, U, U power, F,
 * F power, X list}`. *)
FeynmanParametrization[propagators_List, loopmomenta_List, spmap_] :=
Module[{pre, num, den, nu, a, b, c, i, l, xlist},
  xlist = Table[ToExpression["x" <> ToString[i]], {i, Length[propagators]}];
  den = Sum[propagators[[i]] xlist[[i]], {i, Length[propagators]}] // Expand // ReplaceAll[spmap];
  nu = Length[propagators];
  pre = Gamma[nu];
  num = 1;
  Do[
    If[den === 0, pre = num = den = 0; Break[];];
    a = Coefficient[den, l, 2];
    b = Coefficient[den, l, 1];
    c = Coefficient[den, l, 0];
    pre = pre*Exp[-I Pi d/2] I Pi^(d/2)/(2 Pi)^d Gamma[nu - d/2]/Gamma[nu];
    den = (c a - b^2/4) // Expand // ReplaceAll[spmap] // #/num & // Together;
    If[Not[PolynomialQ[den, xlist]], Error["F is not a polynomial: ", den]];
    num = a;
    nu = nu - d/2;
    ,
    {l, loopmomenta}];
  {pre,(*U*)num,(*U exp*)nu - d/2,(*F*)den,(*F exp*)-nu, xlist}
]

(* Parameterize an integral. Return `{U, F, X list}`. *)
FeynmanUFX[propagators_List, loopmomenta_List, spmap_] :=
    FeynmanParametrization[propagators, loopmomenta, spmap] // {#[[2]], #[[4]], #[[6]]} &

(* Parameterize an integral. Return `{U + F, X list}`. *)
LeePomeranskyPolynomial[propagators_List, loopmomenta_List, spmap_] :=
    FeynmanUFX[propagators, loopmomenta, spmap] // {#[[1]] + #[[2]], #[[3]]} &

(* ## Gamma functions
 *)

(* Convert trigonometry into Gamma functions. Useful to undo the
 * simplifications Mathematica sometimes makes. *)
DeTrig[ex_] := ex /. {
  Csc[x_] :> Gamma[x/Pi] Gamma[1 - x/Pi] / Pi,
  Sin[x_] :> Pi / Gamma[x/Pi] / Gamma[1 - x/Pi]
}
