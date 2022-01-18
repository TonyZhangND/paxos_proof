include "types.dfy"
include "network.dfy"
include "agents.dfy"
include "synod.dfy"
include "proof_agreement_invariants.dfy"

module Proof_Helper {
import opened Network
import opened Agents
import opened Types
import opened Synod
import opened Proof_Agreement_Invs


/*****************************************************************************************
*                                 Single State Helpers                                   *
*****************************************************************************************/

// lemma Lemma_DecidedImpliesQuorumOfAccepts(c:Constants, ds:DistrSys, idx:int) 
//     requires c.WF() && ds.WF(c)
//     requires c.ValidLdrIdx(idx) && LeaderHasDecided(c, ds, idx);
//     requires LdrAcceptsSetCorrespondToAcceptMsg(c, ds)
//     requires LeaderHasQuorumOfAccepts(c, ds, idx)
//     ensures exists qrm :: QuorumOfAcceptMsgs(c, ds, qrm, ds.leaders[idx].ballot)
// {
//     var l, b, v := ds.leaders[idx], ds.leaders[idx].ballot, ds.leaders[idx].val;
//     var qrm:set<Packet> := {};
//     var accepts := l.accepts;
//     var sentPackets := ds.network.sentPackets;
//     var i := 0;
//     while i < c.f + 1 
//         decreases c.f+1 - i
//         invariant |accepts| == c.f+1 - i
//         invariant |qrm| == i
//         invariant UniqueSources(qrm)
//         invariant forall s | s in accepts :: 
//             (forall p | p in qrm :: p.src != s)
//         invariant forall s | s in accepts :: s in l.accepts
//         invariant forall p | p in qrm :: p.msg.Accept?
//         invariant forall p | p in qrm :: p.msg.bal == b
//         invariant forall p | p in qrm :: p in sentPackets;
//         invariant forall p | p in qrm :: p.dst == Id(Ldr, idx);
//     {
//         var s :| s in accepts;
//         var pkt := Packet(s, Id(Ldr, idx), Accept(b, v));
//         qrm := qrm + {pkt};
//         accepts := accepts - {s};
//         i := i + 1;
//     }
//     assert QuorumOfAcceptMsgs(c, ds, qrm, b);
// }


lemma lemma_IdSetCover(c:Constants, ds:DistrSys, qrm1:set<Id>, qrm2:set<Id>, e:Id)
    requires c.WF() && ds.WF(c)
    requires AllPacketsValid(c, ds)
    requires forall id | id in qrm1 :: c.ValidAccId(id)
    requires forall id | id in qrm2 :: c.ValidAccId(id)
    requires c.ValidAccId(e)
    requires qrm1 * qrm2 == {}  // disjoint
    requires |qrm1| + |qrm2| >= 2*c.f+1
    ensures e in qrm1 || e in qrm2
{
    var acc_ids := setFromSeq(c.acc_ids);
    assert e in acc_ids;
    lemma_Set_Cover(qrm1, qrm2, acc_ids);
}



lemma lemma_QuorumIntersection(c:Constants, ds:DistrSys, p1_qrm:set<Packet>, p1_bal:Ballot, p2_qrm:set<Packet>, p2_bal:Ballot)
returns (acc_id:Id)
    requires c.WF() && ds.WF(c)
    requires AllPacketsValid(c, ds)
    requires QuorumOfPromiseMsgs(c, ds, p1_qrm, p1_bal)
    requires QuorumOfAcceptMsgs(c, ds, p2_qrm, p2_bal)
    ensures acc_id.agt == Acc && c.ValidAccIdx(acc_id.idx)
    ensures && (exists prom_p : Packet :: prom_p in p1_qrm && prom_p.src == acc_id)
            && (exists acc_p : Packet :: acc_p in p2_qrm && acc_p.src == acc_id)
{
    var p1_src_qrm := extractPacketSources(p1_qrm);
    var p2_src_qrm := extractPacketSources(p2_qrm);
    assert forall id | id in p1_src_qrm :: id in c.acc_ids;
    assert forall id | id in p2_src_qrm :: id in c.acc_ids;

    if forall id | id in c.acc_ids :: !(id in p1_src_qrm && id in p2_src_qrm) {
        assert seqIsUnique(c.acc_ids);
        var acc_ids := setFromSeq(c.acc_ids);
        assert |acc_ids| == 2*c.f+1;
        var e := lemma_Set_Intersection(p1_src_qrm, p2_src_qrm, acc_ids);
        assert e in acc_ids && e in p1_src_qrm && e in p2_src_qrm;
        assert false;
    }
    acc_id :| acc_id in c.acc_ids && acc_id in p1_src_qrm && acc_id in p2_src_qrm;
}


/* If (b,v) is chosen, then there must be a quorum of Promise for b */
lemma lemma_ChosenImpliesPromiseQrm(c:Constants, ds:DistrSys, b:Ballot, v:Value) returns (qrm:set<Packet>)
    requires Agreement_Chosen_Inv(c, ds)
    requires Chosen(c, ds, b, v) 
    ensures QuorumOfPromiseMsgs(c, ds, qrm, b)
{
    assert exists q :: QuorumOfPromiseMsgs(c, ds, q, b);
    qrm :| QuorumOfPromiseMsgs(c, ds, qrm, b);
}


/* If (b,v) is chosen, then is must have been proposed */
lemma lemma_ChosenImpliesProposeMsg(c:Constants, ds:DistrSys, b:Ballot, v:Value) returns (prop:Packet)
    requires c.WF() && ds.WF(c)
    requires AllPacketsValid(c, ds)
    requires Agreement_Chosen_Inv_Common(c, ds)
    requires Chosen(c, ds, b, v) 
    ensures prop in ds.network.sentPackets && prop.msg.Propose? 
    ensures prop.msg.val == v && prop.msg.bal == b
{
    assert exists acc :: 
            && acc in ds.network.sentPackets 
            && acc.msg.Propose? 
            && acc.msg.val == v && acc.msg.bal == b;
    var acc :| acc in ds.network.sentPackets && acc.msg.Propose? && acc.msg.val == v && acc.msg.bal == b;
    assert exists prop_p :: 
        && prop_p in ds.network.sentPackets
        && prop_p.msg.Propose?
        && prop_p.msg.bal == b
        && prop_p.msg.val == v;
    prop :| prop in ds.network.sentPackets && prop.msg.Propose? && prop.msg.bal == b && prop.msg.val == v;
}



lemma {:axiom} BallotInductionAxiom1(c:Constants, ds:DistrSys, accpt:Packet, b:Ballot, v:Value) 
    requires c.WF() && ds.WF(c)
    requires isAcceptPkt(ds, accpt)
    requires BalLtEq(b, accpt.msg.bal)
    requires accpt.msg.bal == b ==>  accpt.msg.val == v
    requires BalLt(b, accpt.msg.bal) ==> 
        (exists accpt2:Packet :: 
            && isAcceptPkt(ds, accpt2) 
            && BalLtEq(b, accpt2.msg.bal) && BalLt(accpt2.msg.bal, accpt.msg.bal)
            && accpt2.msg.val == accpt.msg.val)
    ensures accpt.msg.val == v
{
    assume false;
    // This is axiomatic
}


/*****************************************************************************************
*                                  Two State Helpers                                     *
*****************************************************************************************/


/* If no new Accept messages sent in this step, then no new (b, v)'s are chosen. */
lemma lemma_NoNewAcceptsImpliesNoNewChosen(
c:Constants, ds:DistrSys, ds':DistrSys)
    requires Agreement_Chosen_Inv(c, ds)
    requires ds'.WF(c) && Trivialities(c, ds')
    requires Next(c, ds, ds')
    requires forall p:Packet | isAcceptPkt(ds', p) :: p in ds.network.sentPackets
    ensures forall b, v | Chosen(c, ds', b, v) :: Chosen(c, ds, b, v) 
{
    forall v, b | Chosen(c, ds', b, v)
    ensures Chosen(c, ds, b, v) {
        if !Chosen(c, ds, b, v) {
            var qrm :| && QuorumOfAcceptMsgs(c, ds', qrm, b)
                       && AccPacketsHaveValueV(qrm, v);
            assert forall p | p in qrm :: p in ds.network.sentPackets;
            assert QuorumOfAcceptMsgs(c, ds, qrm, b);
            assert Chosen(c, ds, b, v);
            assert false;
        }
    }
}


/* All new packets are spawned in sendIos, and anything in sendIos goes into the network */
lemma lemma_NewPacketsComeFromSendIos(
    c:Constants, ds:DistrSys, ds':DistrSys, actor:Id, recvIos:seq<Packet>, sendIos:seq<Packet>)
    requires Next(c, ds, ds')
    requires PaxosNextOneAgent(c, ds, ds', actor, recvIos, sendIos)
    ensures forall p | p in ds'.network.sentPackets && p !in ds.network.sentPackets :: p in sendIos
    ensures forall p | p in sendIos :: p in ds'.network.sentPackets
{
    var e, e' := ds.network, ds'.network;
    var sendSet := set s | s in sendIos;
    assert forall p | p in e'.sentPackets && p !in e.sentPackets :: p in sendSet;
}


/* If a new value is chosen in this step, then this step must be an AcceptorAccept step */
lemma lemma_NewChosenImpliesAcceptStep(
c:Constants, ds:DistrSys, ds':DistrSys, actor:Id, recvIos:seq<Packet>, sendIos:seq<Packet>, b:Ballot, v:Value) 
    requires c.WF() && ds.WF(c) && ds'.WF(c)
    requires AllPacketsValid(c, ds) && AllPacketsValid(c, ds')
    requires Next(c, ds, ds')
    requires PaxosNextOneAgent(c, ds, ds', actor, recvIos, sendIos)
    requires c.ValidAccId(actor)
    requires !Chosen(c, ds, b, v)
    requires Chosen(c, ds', b, v)
    ensures recvIos[0].msg.Propose?
    ensures AcceptorAccept(ds.acceptors[actor.idx], ds'.acceptors[actor.idx], recvIos[0], sendIos)   
{}


/* If a new value is chosen in this step, then Accept(actor, _, (b, v)) must be the only new packet */
lemma lemma_NewChosenImpliesOneNewAcceptPacket(
c:Constants, ds:DistrSys, ds':DistrSys, actor:Id, recvIos:seq<Packet>, sendIos:seq<Packet>, b:Ballot, v:Value) 
returns (p:Packet)
    requires c.WF() && ds.WF(c) && ds'.WF(c)
    requires AllPacketsValid(c, ds) && AllPacketsValid(c, ds')
    requires OneValuePerBallot_AcceptMsg(c, ds')
    requires Next(c, ds, ds')
    requires PaxosNextOneAgent(c, ds, ds', actor, recvIos, sendIos)
    requires c.ValidAccId(actor)
    requires recvIos[0].msg.Propose?
    requires !Chosen(c, ds, b, v)
    requires Chosen(c, ds', b, v)
    ensures p == Packet(actor, recvIos[0].src, Accept(b, v))
    ensures p !in ds.network.sentPackets && p in ds'.network.sentPackets
    ensures forall p' | p' in ds'.network.sentPackets && p' != p :: p' in ds.network.sentPackets
    ensures forall qrm | QuorumOfAcceptMsgs(c, ds', qrm, b) :: p in qrm
{
    p := Packet(actor, recvIos[0].src, Accept(b, v));
    assert p in ds'.network.sentPackets;
    forall qrm | QuorumOfAcceptMsgs(c, ds', qrm, b) 
    ensures p in qrm
    {
        if p !in qrm {
            assert QuorumOfAcceptMsgs(c, ds, qrm, b);
            assert AccPacketsHaveValueV(qrm, v);
            assert Chosen(c, ds, b, v);
            assert false;
        }
    }
}


/* If a new value (b, v) is chosen in this step, the incoming proposal must have ballot b and value v */
lemma lemma_NewChosenImpliesIncomingProposalBV(
c:Constants, ds:DistrSys, ds':DistrSys, actor:Id, recvIos:seq<Packet>, sendIos:seq<Packet>, b:Ballot, v:Value) 
    requires c.WF() && ds.WF(c) && ds'.WF(c)
    requires AllPacketsValid(c, ds) && AllPacketsValid(c, ds')
    requires Next(c, ds, ds')
    requires PaxosNextOneAgent(c, ds, ds', actor, recvIos, sendIos)
    requires c.ValidAccId(actor)
    requires recvIos[0].msg.Propose?
    requires !Chosen(c, ds, b, v)
    requires Chosen(c, ds', b, v)
    ensures recvIos[0].msg.bal == b
    ensures recvIos[0].msg.val == v
{}


/* If this step is an AcceptorAccept step, then no new promises sent */
lemma lemma_NoPromiseSentInAcceptStep(
c:Constants, ds:DistrSys, ds':DistrSys, actor:Id, recvIos:seq<Packet>, sendIos:seq<Packet>) 
    requires c.WF() && ds.WF(c) && ds'.WF(c)
    requires AllPacketsValid(c, ds) && AllPacketsValid(c, ds')
    requires Next(c, ds, ds')
    requires c.ValidAccId(actor)
    requires PaxosNextOneAgent(c, ds, ds', actor, recvIos, sendIos)
    requires recvIos[0].msg.Propose?
    requires AcceptorAccept(ds.acceptors[actor.idx], ds'.acceptors[actor.idx], recvIos[0], sendIos);   
    ensures forall p | isPromisePkt(ds', p) :: p in ds.network.sentPackets
{}




/*****************************************************************************************
*                                  Stateless Helpers                                     *
*****************************************************************************************/


lemma lemma_HighestPromiseValNilImpliesAllBottom(pset:set<Packet>) 
    requires |pset| > 0
    requires forall p | p in pset && p.msg.Promise? :: p.msg.vb.v == Nil <==> p.msg.vb.b == Bottom
    ensures PromisePktWithHighestBallot(pset).msg.vb.v == Nil ==> 
    (forall p | p in pset && p.msg.Promise? :: p.msg.vb.b == Bottom)
{
    if PromisePktWithHighestBallot(pset).msg.vb.v == Nil {
        forall p | p in pset && p.msg.Promise? 
        ensures p.msg.vb.b == Bottom
        {
            if p.msg.vb.b != Bottom {
                assert BalGt(Bottom, p.msg.vb.b);
                assert PromisePktWithHighestBallot(pset).msg.vb.b != Bottom;
                assert PromisePktWithHighestBallot(pset).msg.vb.v != Nil;
                assert false;
            }
        }
    }
}

lemma lemma_PromisePktWithHighestBallotProperty(pset:set<Packet>, p:Packet, v:Value)
    requires |pset| > 0
    requires p.msg.Promise?
    requires p in pset;
    requires forall p' | p' in pset && p'.msg.Promise? && BalLtEq(p.msg.vb.b, p'.msg.vb.b) :: p'.msg.vb.v == v
    ensures PromisePktWithHighestBallot(pset).msg.vb.v == v
{}

lemma lemma_NegBalLtEqSynonyms(b1:Ballot, b2:Ballot) 
    requires !BalLtEq(b1, b2)
    ensures BalGt(b1, b2)
    ensures BalLt(b2, b1)
{}

lemma lemma_BalLtSynonyms(b1:Ballot, b2:Ballot) 
    requires BalLt(b1, b2)
    ensures BalGt(b2, b1)
    ensures !BalLtEq(b2, b1)
{}

lemma lemma_BalLtEqTransitivity(b1:Ballot, b2:Ballot, b3:Ballot) 
    requires BalLtEq(b1, b2)
    requires BalLtEq(b2, b3)
    ensures BalLtEq(b1, b3)
{}

lemma lemma_BalLtTransitivity1(b1:Ballot, b2:Ballot, b3:Ballot) 
    requires BalLt(b1, b2)
    requires BalLtEq(b2, b3)
    ensures BalLt(b1, b3)
    ensures BalGt(b3, b1)
{}


lemma {:axiom} lemma_SingleElemList<T>(s:seq<T>, e:T) 
    requires |s| == 1;
    requires e == s[0]
    ensures forall e' | e' in s :: e' == e
{
    // This is axiomatic
}


lemma {:axiom} lemma_Set_Cover<T>(S1:set<T>, S2:set<T>, U:set<T>)
    requires S1 <= U 
    requires S2 <= U
    requires S1 * S2 == {}
    requires |S1| + |S2| >= |U|
    ensures S1 + S2 == U
{
    // This is axiomatic
    assume false;
}

lemma {:axiom} lemma_Set_DisjointSets<T>(S1:set<T>, S2:set<T>)
    requires forall e | e in S1 :: e !in S2
    ensures S1 * S2 == {}
{
    // This is axiomatic
}


lemma lemma_Set_Intersection(S1:set<Id>, S2:set<Id>, U:set<Id>) returns (e:Id)
    requires |S1| > |U|/2
    requires |S2| > |U|/2
    requires forall id | id in S1 :: id in U
    requires forall id | id in S2 :: id in U
    ensures e in U && e in S1 && e in S2
{
    // TODO: assume for now
    assume false;
}


lemma lemma_Set_MinusElem<T>(S:set<T>, e:T, n:int) 
    requires |S| == n && n > 0
    requires e in S
    ensures |S - {e}| == n - 1
{}

/*****************************************************************************************
*                                        Utils                                           *
*****************************************************************************************/




function {:opaque} extractPacketSources(S:set<Packet>) : (res:set<Id>) 
    decreases S
    ensures forall id | id in res :: (exists p :: p in S && p.src == id)
    ensures forall p | p in S :: p.src in res
    ensures UniqueSources(S) ==> |res| == |S|
{ 
    if |S| == 0 then {}
    else 
        var p :| p in S;
        {p.src} + extractPacketSources(S - {p})
}


function {:opaque} setFromSeq(a:seq<Id>) : (res:set<Id>) 
    decreases a
    ensures forall i | 0 <= i < |a| :: a[i] in res
    ensures forall id | id in res :: (exists i :: 0 <= i < |a| && a[i] == id)
    ensures seqIsUnique(a) ==> |a| == |res|
{ 
    if |a| == 0 then {}
    else 
        {a[0]} + setFromSeq(a[1..])
}
}