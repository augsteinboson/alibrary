(* # QCD Feynman rules
 *
 * These are Feynman rules for a QCD-like model with light
 * quarks (qQ), heavy quarks (tT), gluons (g), ghosts (cC), and
 * external photons (A), Z bosons (Z), and Higgs-like scalars
 * coupled to the heavy quarks (H).
 *)

(* ## QGraf model
 *)

$QGrafModel = "\
# Photons
[A, A, +, external]
# Higgs'
[H, H, +, external]
# Z bosons
[Z, Z, +, external]
# Gluons
[g, g, +]
# Quarks & antiquarks
[q, Q, -]
# Heavy quarks & antiquarks
[t, T, -]
# Ghosts (gluonic)
[c, C, -]
# Vertices
[A, q, Q]
[Z, q, Q]
[g, q, Q]
[g, c, C]
[g, g, g]
[g, g, g, g]
[A, t, T]
[Z, t, T]
[g, t, T]
[H, t, T]";

(* ## Field classification
 *)

$MasslessFieldPattern = "q"|"Q"|"g"|"A";

(* ## Propagators
 *)

Amplitude[P["q", fi1_, fi2_, _, _, p_]] :=
  I deltaflv[fi1, fi2] deltafun[fi2, fi1] \
  gammachain[slash[p], spn[fi2], spn[fi1]] den[p]
Amplitude[P["t", fi1_, fi2_, _, _, p_]] :=
  I deltaflvt[fi1, fi2] deltafun[fi2, fi1] \
  (gammachain[slash[p], spn[fi2], spn[fi1]] + mt1 gammachain[spn[fi2], spn[fi1]]) den[p, mt2]
Amplitude[P["g", fi1_, fi2_, _, _, p_]] :=
  -I deltaadj[fi1, fi2] (deltalor[fi1, fi2] den[p] -
    Xi momentum[p, lor[fi1]] momentum[p, lor[fi2]] den[p]^2)
Amplitude[P["H", fi1_, fi2_, _, _, p_]] := I den[p]
Amplitude[P["c", fi1_, fi2_, _, _, p_]] := I deltaadj[fi1, fi2] den[p]

(* ## Vertices
 *)

Amplitude[V[_, "gqQ", fi1_, p1_, fi2_, p2_, fi3_, p3_]] :=
  I gs deltaflv[fi2, fi3] gammachain[gamma[lor[fi1]], spn[fi3],
  spn[fi2]] colorT[adj[fi1], fun[fi3], fun[fi2]]
Amplitude[V[_, "gtT", fi1_, p1_, fi2_, p2_, fi3_, p3_]] :=
  I gs deltaflvt[fi2, fi3] gammachain[gamma[lor[fi1]], spn[fi3],
  spn[fi2]] colorT[adj[fi1], fun[fi3], fun[fi2]]
Amplitude[V[_, "gcC", fi1_, p1_, fi2_, p2_, fi3_, p3_]] :=
  -gs colorf[adj[fi1], adj[fi2], adj[fi3]] momentum[-p3, lor[fi1]]
Amplitude[V[_, "AqQ", fi1_, p1_, fi2_, p2_, fi3_, p3_]] :=
  (* ge *) I deltaflv[fi2, fi3] deltafun[fi3, fi2] chargeQ[flv[fi2]] \
  gammachain[gamma[lor[fi1]], spn[fi3], spn[fi2]]
Amplitude[V[_, "AtT", fi1_, p1_, fi2_, p2_, fi3_, p3_]] :=
  (* ge *) I deltaflvt[fi2, fi3] deltafun[fi3, fi2] chargeQt[flv[fi2]] \
  gammachain[gamma[lor[fi1]], spn[fi3], spn[fi2]]
Amplitude[V[_, "ZqQ", fi1_, p1_, fi2_, p2_, fi3_, p3_]] :=
  (* gz *) I deltaflv[fi2, fi3] deltafun[fi3, fi2] (
    chargeV[flv[fi2]] gammachain[gamma[lor[fi1]], spn[fi3], spn[fi2]] -
    (* gamma5[mu] == gamma[mu] gamma5 *)
    chargeA[flv[fi2]] gammachain[gamma5[lor[fi1]], spn[fi3], spn[fi2]]
  )
Amplitude[V[_, "ggg", fi1_, p1_, fi2_, p2_, fi3_, p3_]] :=
  gs colorf[adj[fi1], adj[fi2], adj[fi3]] (
    deltalor[fi1, fi2] momentum[p1 - p2, lor[fi3]] +
    deltalor[fi2, fi3] momentum[p2 - p3, lor[fi1]] +
    deltalor[fi3, fi1] momentum[p3 - p1, lor[fi2]]
  )
Amplitude[V[vi_, "gggg", fi1_, p1_, fi2_, p2_, fi3_, p3_, fi4_, p4_]] :=
  Module[{adjX = adj[1000 + vi]},
    -I gs^2 (
      colorf[adjX, adj[fi1], adj[fi2]] colorf[adjX, adj[fi3], adj[fi4]]
        (deltalor[fi1, fi3] deltalor[fi2, fi4] -
          deltalor[fi1, fi4] deltalor[fi2, fi3]) +
      colorf[adjX, adj[fi1], adj[fi3]] colorf[adjX, adj[fi4], adj[fi2]]
        (deltalor[fi1, fi4] deltalor[fi2, fi3] -
          deltalor[fi1, fi2] deltalor[fi3, fi4]) +
      colorf[adjX, adj[fi1], adj[fi4]] colorf[adjX, adj[fi2], adj[fi3]]
        (deltalor[fi1, fi2] deltalor[fi3, fi4] -
          deltalor[fi1, fi3] deltalor[fi2, fi4])
    )
  ]
Amplitude[V[_, "HtT", fi1_, p1_, fi2_, p2_, fi3_, p3_]] :=
  gH deltaflvt[fi2, fi3] deltafun[fi2, fi3] gammachain[spn[fi3], spn[fi2]]

(* ## Final states
 *)

CutAmplitudeGlue[F[f:"H", fi_, _, mom_], F[f_, fi_, _, mom_]] := 1
CutAmplitudeGlue[F[f:"g", fi_, _, mom_], F[f_, fi_, _, mom_]] := (* -g_mn d_ab *)
  -delta[lor[fi], lor[fi] // AmpConjugate] delta[adj[fi], adj[fi] // AmpConjugate]
CutAmplitudeGlue[F[f:"c"|"C", fi_, _, mom_], F[f_, fi_, _, mom_]] := (* d_ab *)
  delta[adj[fi], adj[fi] // AmpConjugate]
CutAmplitudeGlue[F[f:"Q", fi_, _, mom_], F[f_, fi_, _, mom_]] := (* p^slash d_ij d_f1f2 *)
  gammachain[slash[mom], spn[fi], spn[fi] // AmpConjugate] *
  delta[fun[fi], fun[fi] // AmpConjugate] *
  deltaf[flv[fi], flv[fi] // AmpConjugate]
CutAmplitudeGlue[F[f:"q", fi_, _, mom_], F[f_, fi_, _, mom_]] := (* p^slash d_ij d_f1f2 *)
  gammachain[slash[mom], spn[fi] // AmpConjugate, spn[fi]] *
  delta[fun[fi], fun[fi] // AmpConjugate] *
  deltaf[flv[fi], flv[fi] // AmpConjugate]
CutAmplitudeGlue[F[f:"T", fi_, _, mom_], F[f_, fi_, _, mom_]] := (* (p^slash - mt1) d_ij d_f1f2 *)
  (gammachain[slash[mom], spn[fi], spn[fi] // AmpConjugate] - mt1 gammachain[spn[fi], spn[fi] // AmpConjugate]) *
  delta[fun[fi], fun[fi] // AmpConjugate] *
  deltaft[flv[fi], flv[fi] // AmpConjugate]
CutAmplitudeGlue[F[f:"t", fi_, _, mom_], F[f_, fi_, _, mom_]] := (* (p^slash + mt1) d_ij d_f1f2 *)
  (gammachain[slash[mom], spn[fi] // AmpConjugate, spn[fi]] + mt1 gammachain[spn[fi] // AmpConjugate, spn[fi]]) *
  delta[fun[fi], fun[fi] // AmpConjugate] *
  deltaft[flv[fi], flv[fi] // AmpConjugate]

(* ## Field styles for [[DiagramToGraphviz]].
 *)

FieldGraphvizColor["q"|"Q"] = 6;
FieldGraphvizColor["t"|"T"] = 6;
FieldGraphvizColor["g"] = 4;
FieldGraphvizColor["c"|"C"] = 8;
FieldGraphvizColor["H"] = 10;
FieldGraphvizColor["A"|"Z"] = 10;

(* ## Field styles for [[DiagramToTikZ]].
 *)

FieldTikZStyle["q"|"Q"] = "fermion";
FieldTikZStyle["t"|"T"] = "massive fermion";
FieldTikZStyle["g"] = "gluon";
FieldTikZStyle["c"|"C"] = "ghost";
FieldTikZStyle["H"] = "scalar";
FieldTikZStyle["A"|"Z"] = "vector";
