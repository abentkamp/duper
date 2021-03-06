import Duper.Simp
import Duper.Util.ProofReconstruction

namespace Duper
open RuleM
open SimpResult
open Lean

def mkElimDupLitProof (refs : Array Nat) (premises : Array Expr) (parents: Array ProofParent) (c : Clause) : MetaM Expr := do
  let premise := premises[0]
  let parent := parents[0]
  Meta.forallTelescope c.toForallExpr fun xs body => do
    let cLits := c.lits.map (fun l => l.map (fun e => e.instantiateRev xs))
    let mut proofCases := #[]
    for i in [:parent.clause.lits.size] do
      let proofCase ← Meta.withLocalDeclD `h parent.clause.lits[i].toExpr fun h => do
        Meta.mkLambdaFVars #[h] $ ← orIntro (cLits.map Lit.toExpr) refs[i] h
      proofCases := proofCases.push proofCase
    let proof ← orCases (parent.clause.lits.map Lit.toExpr) proofCases
    let proof ← Meta.mkLambdaFVars xs $ mkApp proof premise
    trace[Meta.debug] "proof: {proof}"
    trace[Meta.debug] "clause: {c}"
    return proof

/-- Remove duplicate literals -/
def elimDupLit : MSimpRule := fun c => do
  let mut newLits := #[]
  let mut refs := #[]
  for i in [:c.lits.size] do
    match newLits.getIdx? c.lits[i] with
    | some j => do
      refs := refs.push j
    | none => do
      refs := refs.push newLits.size
      newLits := newLits.push c.lits[i]
      
  if newLits.size = c.lits.size then
    return Unapplicable
  else
    return Applied [(MClause.mk newLits, some (mkElimDupLitProof refs))]

end Duper