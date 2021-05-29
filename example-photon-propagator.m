(* # Photon propagator
 *
 * In this example we will calculate symbolically and evaluate
 * numerically a photon propagator. The physical model is QCD
 * with generic color group (symbolic Nc, Ca, Cf, etc), `Nf`
 * light quarks, and `Nft` heavy quarks of squared mass `mt2`.
 *)

(* To start off, for interactive development it is convenient
 * to reduce the width of Mathematica formatted output to 65
 * characters, and force it to clear the history (the `Out[]`
 * variables) so that old expressions would not linger on in
 * the memory.
 *)

SetOptions[$Output, PageWidth -> 65];
$HistoryLength = 2;

(* Load *alibrary*.
 *)

Get["alibrary.m"];

(* We shall calculate the corrections of order `alpha_s^NLOOPS`,
 * so define `NLOOPS`.
 *)

NLOOPS = 2;

(* Generate the diagrams with QGraf by the way of [[mkdia.py]].
 *)

SafeRun["./mkdia.py dia-A-A-", NLOOPS, ".m"];
diagrams = SafeGet[MkString["dia-A-A-", NLOOPS, ".m"]];
Print["Loaded ", diagrams//Length, " diagrams"];

(* Because the (amputated) photon propagator has open Lorentz
 * indices corresponding to the incoming and outgoing photons,
 * we need to project it to scalar values somehow. Here is the
 * projector we shall use.
 *)

projector = delta[lor[-1], lor[-2]] / (d-1);

(* Apply Feynman rules to get amplitudes out of diagrams.
 *)

amplitudes = diagrams // Map[Amplitude[#] * projector&];

(* Cleanup scaleless integrals. Some of these show up as
 * propagators with zero momentum, which means that a part of the
 * graph is disconnected from the rest, and thus scaleless. We can
 * set these to zero immediately.
 *)

amplitudes2 = amplitudes /. den[0] -> 0 /. momentum[0,_] -> 0;
Print["Non-zero amplitudes: ", amplitudes2//Count[Except[0]], " of ", amplitudes2//Length];

(* In this particular example there is a set of diagrams that
 * are zero by the color factors. For example, those with subdiagrams
 * where a photon turns into a single gluon. In principle we could
 * try to skip these during diagram generation, but we don’t need
 * to. Lets compute color factors instead, and see what turns to zero.
 *)

amplitudes3 = amplitudes2 // RunThroughForm[{ "#call colorsum\n" }];
Print["Non-zero amplitudes: ", amplitudes3//Count[Except[0]], " of ", amplitudes3//Length];

(* Next we want to define the integral families onto which
 * we shall map the integrals, and which will be used in the IBP
 * reduction later.
 *
 * To this end, start with the set of denominators per diagram.
 *)

loopmomenta = diagrams // CaseUnion[l1|l2|l3|l4|l5];
externalmomenta = diagrams // CaseUnion[q|q1|q2|q3|q4|q5|p1|p2|p3|p4|p5];
Print["External momenta: ", externalmomenta];
Print["Loop momenta: ", loopmomenta];
FailUnless[Length[loopmomenta] === NLOOPS];

denominatorsets = amplitudes3 // NormalizeDens // Map[
  CaseUnion[_den] /* Select[NotFreeQ[Alternatives@@loopmomenta]]
];
Print["Unique denominator sets: ", denominatorsets // DeleteCases[{}] // Union // Length];

(* In principle we could define the integral families by the
 * denominator sets above, one family per denominator set. This
 * is not very efficient though, as there are symmetries between
 * those families. It’s best to first eliminate denominator
 * sets that are symmetric to others.
 *
 * The symmetries manifest most directly in the Feynman parameter
 * space, as permutations of the parameters. In the momenta space
 * this corresponds to loop momenta shifts, and we would like
 * to have a set of momenta shifts that would make symmetric
 * families explicitly identical, or identical to subsets of bigger
 * families, so we could test if a family is symmetric by just
 * asking if the set of denominators a subset of another family.
 *
 * The tool to compute this momenta mapping is [Feynson], and
 * the interface to it is [[SymmetryMaps]].
 *
 * [feynson]: https://github.com/magv/feynson
 *)

$Feynson = "~/dev/feynson/feynson";
momentamaps = SymmetryMaps[denominatorsets, loopmomenta, externalmomenta];
Print["Found ", momentamaps // DeleteCases[{}] // Length, " momenta mappings"];

symmetrizeddenominatorsets =
  MapThread[ReplaceAll, {denominatorsets, momentamaps}] //
  NormalizeDens;

(* Then, the set of unique supersets of the denominator sets is
 * the set of integral families we need.
 *)

{denominatorsupersets, supersetindices} =
  UniqueSupertopologyMapping[symmetrizeddenominatorsets];
Print["Total integral families: ", denominatorsupersets//Length];

(* Let us then construct the IBP basis objects for each unique
 * denominator superset. These objects are just associations storing
 * denominators, and maps from scalar products into the denominators.
 *
 * Also in the case when the denominator set is not sufficient
 * to form the full linear basis of scalar products, we want to
 * complete it; [[CompleteIBPBasis]] will do this for us.
 *)

bases = denominatorsupersets //
  MapIndexed[CompleteIBPBasis[
    First[#2], #1, loopmomenta, externalmomenta, {sp[q,q]->sqrq}
  ]&];

(* OK, now that we have the IBP bases, we can convert the
 * amplitudes to them.
 *
 * One practical thing to start with is to identify the set of
 * sectors (integral family subsets) that correspond to scaleless
 * integrals. This is also done with [Feynson].
 *)

zerosectors = ZeroSectors[bases];

(* Next, just call FORM to do all the tensor summation and
 * conversion to IBP families.
 *)

amplitudesB =
  MapThread[ReplaceAll, {amplitudes3, momentamaps}] //
  # * BID^supersetindices & //
  RunThroughForm[{
    "#call contractmomenta\n",
    "#call sort(after-contractmomenta)\n",
    "#call chaincolorT\n",
    "#call chaingammachain\n",
    "#call flavorsumwithcharge\n",
    "#call colorsum\n",
    "#call sort(after-colorsum)\n",
    "#call polarizationsum\n",
    "#call spinsum\n",
    "#call diractrace\n",
    "#call contractmomenta\n",
    FormCallToB[bases],
    "id mt1^2 = mt2;\n",
    FormCallZeroSectors[zerosectors]
  }] //
  MapWithCliProgress[FasterFactor];

(* Next, lets do the IBP reduction.
 *
 * Now, [[KiraIBP]] is the simple interface to IBP with [Kira].
 * It is probably too simplistic to work automatically for larger
 * examples, but for this problem it’s ideal.
 *
 * [kira]: https://kira.hepforge.org/
 *)

amplitudesBibp = amplitudesB // KiraIBP[bases];

fullamplitude = amplitudesBibp // Apply[Plus] // Bracket[#, _B, Factor]&;

(* A good correctness check is to see if there is any Xi
 * dependence left. None should remain.
 *)

FailUnless[FreeQ[fullamplitude , Xi]];

(* Now we have reduced the amplitude to master integrals.
 *
 * The final step is to insert the values of the masters. Of
 * course the masters here are known analytically, but as an
 * example let us evaluate them numerically with [pySecDec],
 * each up to order 2 in epsilon expansion.
 *
 * [pySecDec]: https://github.com/gudrunhe/secdec
 *)

masters = amplitudesBibp  // CaseUnion[_B];
Print["Master integrals: ", masters // Length];

SecDecCompile["secdectmpdir", bases, masters // Map[{#, 2}&]];

pspoint = { sqrq -> 120/100, mt2 -> 34/100 };

{mastervalues, mastererrors} =
  SecDecIntegrate["secdectmpdir", masters, pspoint] //
  Transpose;

(* Finally we have the value and the uncertainty of the full amplitude.
 *)

value = fullamplitude  /.
  d -> 4 - 2*eps /.
  pspoint /.
  MapThread[Rule, {masters, mastervalues}];

error = fullamplitude /.
  d -> 4 - 2*eps /.
  pspoint /.
  MapThread[Rule, {masters, mastererrors}];
