include "types.dfy"
include "network.dfy"
include "agents.dfy"
include "synod.dfy"
include "proof_helper.dfy"
include "proof_axioms.dfy"
include "proof_agreement_invariants.dfy"

module Proof_Agreement_ChosenProperties_1 {
import opened Network
import opened Agents
import opened Types
import opened Synod
import opened Proof_Helper
import opened Proof_Axioms
import opened Proof_Agreement_Invs


/////////////////        Agreement Sub-Lemma: No existing decision         ///////////////


lemma AgreementChosenInv_NoneChosen(c:Constants, ds:DistrSys, ds':DistrSys) 
    requires Agreement_Chosen_Inv(c, ds)
    requires ds'.WF(c) && Trivialities(c, ds')
    requires Next(c, ds, ds')
    requires Agreement_Chosen_Inv_Common(c, ds')
    requires !SomeValueChosen(c, ds)
    ensures Agreement_Chosen_Inv_ChosenProperties(c, ds')
{
    var actor, recvIos:seq<Packet>, sendIos :| PaxosNextOneAgent(c, ds, ds', actor, recvIos, sendIos);
    if actor.agt == Ldr {
        // If actor is a Leader
        // No values are chosen in this step
        lemma_NoNewAcceptsImpliesNoNewChosen(c, ds, ds');
        assert !SomeValueChosen(c, ds');
    } else {
        // If actor is an Acceptor: This is the tricky case as 
        // some value may be chosen in this step
        AgreementChosenInv_NoneChosen_AccAction(c, ds, ds', actor, recvIos, sendIos);
    }
}


lemma AgreementChosenInv_NoneChosen_AccAction(
c:Constants, ds:DistrSys, ds':DistrSys, actor:Id, recvIos:seq<Packet>, sendIos:seq<Packet>)
    requires Agreement_Chosen_Inv(c, ds)
    requires ds'.WF(c) && Trivialities(c, ds')
    requires Agreement_Chosen_Inv_Common(c, ds')
    requires Next(c, ds, ds')
    requires PaxosNextOneAgent(c, ds, ds', actor, recvIos, sendIos)
    requires c.ValidAccId(actor)
    requires !SomeValueChosen(c, ds)
    ensures Agreement_Chosen_Inv_ChosenProperties(c, ds')
{
    forall b, v | Chosen(c, ds', b, v) 
    ensures Agreement_Chosen_Inv_SomeValChosen(c, ds', b, v)
    {
        lemma_NewChosenImpliesAcceptStep(c, ds, ds', actor, recvIos, sendIos, b, v);
        AgreementChosenInv_NoneChosen_AccAction_NewChosenV(c, ds, ds', actor, recvIos, sendIos, b, v);
    }
}


lemma AgreementChosenInv_NoneChosen_AccAction_NewChosenV(
c:Constants, ds:DistrSys, ds':DistrSys, actor:Id, recvIos:seq<Packet>, sendIos:seq<Packet>, b:Ballot, v:Value)
    requires Agreement_Chosen_Inv(c, ds)
    requires ds'.WF(c) && Trivialities(c, ds')
    requires Agreement_Chosen_Inv_Common(c, ds')
    requires Next(c, ds, ds')
    requires PaxosNextOneAgent(c, ds, ds', actor, recvIos, sendIos)
    requires c.ValidAccId(actor)
    requires recvIos[0].msg.Propose?
    requires AcceptorAccept(ds.acceptors[actor.idx], ds'.acceptors[actor.idx], recvIos[0], sendIos);   
    requires !SomeValueChosen(c, ds)
    requires Chosen(c, ds', b, v)
    requires OneValuePerBallot(c, ds');
    ensures Agreement_Chosen_Inv_SomeValChosen(c, ds', b, v)
{
    AgreementChosenInv_NoneChosen_AccAction_NewChosenV_LargerBallotsPromiseQrms(c, ds, ds', actor, recvIos, sendIos, b, v);
    AgreementChosenInv_NoneChosen_AccAction_NewChosenV_LargerBallotAcceptMsgs(c, ds, ds', actor, recvIos, sendIos, b, v);
    AgreementChosenInv_NoneChosen_AccAction_NewChosenV_LargerBallotAcceptors(c, ds, ds', actor, recvIos, sendIos, b, v);
    AgreementChosenInv_NoneChosen_AccAction_NewChosenV_LargerBallotPromiseMsgs(c, ds, ds', actor, recvIos, sendIos, b, v);
    AgreementChosenInv_NoneChosen_AccAction_NewChosenV_LargerBallotProposeMsgs(c, ds, ds', actor, recvIos, sendIos, b, v);
    AgreementChosenInv_NoneChosen_AccAction_NewChosenV_P2LeaderV(c, ds, ds', actor, recvIos, sendIos, b, v);
}


lemma AgreementChosenInv_NoneChosen_AccAction_NewChosenV_LargerBallotsPromiseQrms(
c:Constants, ds:DistrSys, ds':DistrSys, actor:Id, recvIos:seq<Packet>, sendIos:seq<Packet>, b:Ballot, v:Value)
    requires Agreement_Chosen_Inv(c, ds)
    requires ds'.WF(c) && Trivialities(c, ds')
    requires Agreement_Chosen_Inv_Common(c, ds')
    requires Next(c, ds, ds')
    requires PaxosNextOneAgent(c, ds, ds', actor, recvIos, sendIos)
    requires c.ValidAccId(actor)
    requires recvIos[0].msg.Propose?
    requires AcceptorAccept(ds.acceptors[actor.idx], ds'.acceptors[actor.idx], recvIos[0], sendIos);   
    requires !SomeValueChosen(c, ds)
    requires Chosen(c, ds', b, v)
    ensures LargerBallotsPromiseQrms(c, ds', b)
{
    forall b' | BalLt(b, b') 
    ensures LargerBalQuorumHasSeenB(c, ds', b, b')
    {
        forall qrm':set<Packet> | QuorumOfPromiseMsgs(c, ds', qrm', b') 
        ensures QuorumHasSeenB(c, ds', qrm', b){
            AgreementChosenInv_NoneChosen_AccAction_NewChosenV_LargerBallotsPromiseQrms_helper(c, ds, ds', actor, recvIos, sendIos, b, b', qrm', v);
        }
    }
}

lemma AgreementChosenInv_NoneChosen_AccAction_NewChosenV_LargerBallotsPromiseQrms_helper(
c:Constants, ds:DistrSys, ds':DistrSys, actor:Id, recvIos:seq<Packet>, sendIos:seq<Packet>, b:Ballot, b':Ballot, qrm':set<Packet>, v:Value)
    requires Agreement_Chosen_Inv(c, ds)
    requires ds'.WF(c) && Trivialities(c, ds')
    // Picking individual items from Agreement_Chosen_Inv_Common, faster verification
    requires OneValuePerBallot(c, ds')
    requires PromiseMsgImpliesPromised(c, ds')
    requires PromisedImpliesNoMoreAccepts(c, ds')
    requires AccPromisedBallotLargerThanAccepted(c, ds')
    requires AcceptMsgImpliesAccepted(c, ds')

    requires Next(c, ds, ds')
    requires PaxosNextOneAgent(c, ds, ds', actor, recvIos, sendIos)
    requires c.ValidAccId(actor)
    requires recvIos[0].msg.Propose?
    requires AcceptorAccept(ds.acceptors[actor.idx], ds'.acceptors[actor.idx], recvIos[0], sendIos)   
    requires !SomeValueChosen(c, ds)
    requires Chosen(c, ds', b, v)
    requires BalLt(b, b') 
    requires QuorumOfPromiseMsgs(c, ds', qrm', b')
    ensures QuorumHasSeenB(c, ds', qrm', b)
{
    /* Proof: Suppose otherwise. Then qrm' is in ds, and every Prom in qrm' has promised
    * b', and saw < b. By PromisedImpliesNoMoreAccepts, this means that no Accept(b) messages
    * from any acceptor in qrm'.
    * Call the set of acceptors that chose (b, v) in ds' as qrm. Then qrm and qrm' must be disjoint, 
    * and their union is the set of all acceptors, and qrm is size f. 
    * Now consider the actor taking a step: 
    *   1. If actor is in qrm', it can't accept (b, v). Hence (b,v) not chosen in ds'. C!
    *   2. If actor is in qrm, |qrm| remains f in ds'. C!
    */
    if !QuorumHasSeenB(c, ds', qrm', b) {
        forall prom | prom in qrm' ensures BalLt(prom.msg.vb.b, b) {}
        lemma_NoPromiseSentInNonPromiseStep(c, ds, ds', actor, recvIos, sendIos);
        assert QuorumOfPromiseMsgs(c, ds, qrm', b');
        
        // Get set of acceptors that promised b' (and not seen b) in ds
        var accs_that_promised := extractPacketSources(qrm');
        assert |accs_that_promised| >= c.f + 1;

        // Get set of acceptors that voted to choose (b, v) in ds
        var qrm :| QuorumOfAcceptMsgs(c, ds', qrm, b) && AccPacketsHaveValueV(qrm, v);
        var new_accept_pkt := lemma_NewChosenImpliesOneNewAcceptPacket(c, ds, ds', actor, recvIos, sendIos, b, v);
        var pre_qrm := qrm - {new_accept_pkt};   // set without the latest Accept from ds->ds' actor.
        assert SetOfAcceptMsgs(c, ds, pre_qrm, b);
        lemma_Set_MinusElem(qrm, new_accept_pkt, |qrm|);
        var accs_that_accepted := extractPacketSources(pre_qrm);
        assert |accs_that_accepted| >= c.f;

        // Show that accs_that_promised && accs_that_accepted are disjoint;
        // use PromisedImpliesNoMoreAccepts
        forall id | id in accs_that_promised 
        ensures id !in accs_that_accepted
        {
            var prom :| prom in qrm' && prom.src == id;
            forall accp | accp in qrm 
            ensures accp.src != id
            {
                if accp.src == id {      
                    assert !BalLtEq(accp.msg.bal, prom.msg.vb.b);
                    lemma_BalLtSynonyms(b, b');
                    assert !BalLtEq(prom.msg.bal, accp.msg.bal);
                    assert false;
                }
            }
        }
        axiom_Set_DisjointSets(accs_that_promised, accs_that_accepted);
        // Consider the current actor taking a step
        lemma_IdSetCover(c, ds, accs_that_promised, accs_that_accepted, actor);
        if actor in accs_that_promised {
            assert BalLtEq(b', ds.acceptors[actor.idx].promised);   // by PromiseMsgImpliesPromised
            lemma_BalLtTransitivity1(b, b', ds.acceptors[actor.idx].promised);
            lemma_NewChosenImpliesIncomingProposalBV(c, ds, ds', actor, recvIos, sendIos, b, v);
            assert !AcceptorAccept(ds.acceptors[actor.idx], ds'.acceptors[actor.idx], recvIos[0], sendIos); 
            assert false;
        } else {
            assert actor in accs_that_accepted;
            var p :| p in pre_qrm && p.src == actor && isAcceptPkt(ds, p) && p.msg.bal == b;
            lemma_NewChosenImpliesIncomingProposalBV(c, ds, ds', actor, recvIos, sendIos, b, v);
            assert sendIos[0] == p;
            assert ds'.network.sentPackets == ds.network.sentPackets;
            assert false;       // violates lemma_NewChosenImpliesOneNewAcceptPacket
        }
    }
}


lemma AgreementChosenInv_NoneChosen_AccAction_NewChosenV_LargerBallotAcceptMsgs(
c:Constants, ds:DistrSys, ds':DistrSys, actor:Id, recvIos:seq<Packet>, sendIos:seq<Packet>, b:Ballot, v:Value)
    requires Agreement_Chosen_Inv(c, ds)
    requires ds'.WF(c) && Trivialities(c, ds')
    requires Agreement_Chosen_Inv_Common(c, ds')
    requires Next(c, ds, ds')
    requires PaxosNextOneAgent(c, ds, ds', actor, recvIos, sendIos)
    requires c.ValidAccId(actor)
    requires recvIos[0].msg.Propose?
    requires AcceptorAccept(ds.acceptors[actor.idx], ds'.acceptors[actor.idx], recvIos[0], sendIos)   
    requires !SomeValueChosen(c, ds)
    requires Chosen(c, ds', b, v)
    requires LargerBallotsPromiseQrms(c, ds', b)
    ensures LargerBallotAcceptMsgs(c, ds', b, v)
{
    forall accpt | isAcceptPkt(ds', accpt) && BalLtEq(b, accpt.msg.bal)
    ensures accpt.msg.val == v
    {
        AgreementChosenInv_NoneChosen_AccAction_NewChosenV_LargerBallotAcceptMsgs_helper(c, ds, ds', 
            actor, recvIos, sendIos, b, v, accpt, accpt.msg.bal, accpt.msg.val);
    }
}


lemma AgreementChosenInv_NoneChosen_AccAction_NewChosenV_LargerBallotAcceptMsgs_helper(
c:Constants, ds:DistrSys, ds':DistrSys, actor:Id, recvIos:seq<Packet>, sendIos:seq<Packet>, b:Ballot, v:Value,
accpt:Packet, b1:Ballot, v':Value)
    decreases b1
    requires Agreement_Chosen_Inv(c, ds)
    requires ds'.WF(c) && Trivialities(c, ds')
    // Picking individual items from Agreement_Chosen_Inv_Common, faster verification
    // requires Agreement_Chosen_Safety(c, ds') 
    requires OneValuePerBallot(c, ds')
    requires AcceptMsgImpliesProposeMsg(c, ds')
    requires ProposeMsgImpliesQuorumOfPromise(c, ds')
    requires PromiseVBImpliesAcceptMsg(c, ds')
    requires PromiseMsgBalLargerThanAcceptedItSees(c, ds')

    requires Next(c, ds, ds')
    requires PaxosNextOneAgent(c, ds, ds', actor, recvIos, sendIos)
    requires c.ValidAccId(actor)
    requires recvIos[0].msg.Propose?
    requires AcceptorAccept(ds.acceptors[actor.idx], ds'.acceptors[actor.idx], recvIos[0], sendIos)
    requires !SomeValueChosen(c, ds)
    requires Chosen(c, ds', b, v)
    requires LargerBallotsPromiseQrms(c, ds', b)
    requires isAcceptPkt(ds', accpt) && BalLtEq(b, accpt.msg.bal)
    requires b1 == accpt.msg.bal
    requires v' == accpt.msg.val
    ensures accpt.msg.val == v
{
    /* Consider accpt Accept(b1, v') message, b1 >b. By AcceptMsgImpliesProposeMsg, there is a Propose(b1, v') in the network.
    * By ProposeMsgImpliesQuorumOfPromise, there is a quorum qrm1 of promise b1 packets, such that 
    * PromisePktWithHighestBallot(qrm1).msg.vb.v == v'. By LargerBallotsPromiseQrms, qrm1 must also see (b, v).
    * There are now two cases:
    *   1. PromisePktWithHighestBallot(qrm1).msg.vb.b == b. Then we are done, by OneValuePerBallot.
    *   2. PromisePktWithHighestBallot(qrm1).msg.vb.b == b2. By PromiseMsgBalLargerThanAcceptedItSees, b2 < b1.
    *          I.e. b < b2 < b1.
    * This means that there is a Accept(b2, v') message. And we go down recursively. 
    * Since there are finite number of ballots (say, i) between b1 and b, after i iterations of step 2, 
    * we must hit b eventually, and QED.
    */
    var b1, v' := accpt.msg.bal, accpt.msg.val;
    if b1 == b {
        var chosen_qrm_member :|    && isAcceptPkt(ds', chosen_qrm_member)
                                    && chosen_qrm_member.msg.bal == b
                                    && chosen_qrm_member.msg.val == v;
        assert chosen_qrm_member.msg.val == accpt.msg.val;  // by OneValuePerBallot_AcceptMsg
    } else {
        var prop1 :| isProposePkt(ds', prop1) && prop1.msg == Propose(b1, v');
        var qrm1 :| QuorumOfPromiseMsgs(c, ds', qrm1, b1)
                    && (|| PromisePktWithHighestBallot(qrm1).msg.vb.v == v'
                        || PromisePktWithHighestBallot(qrm1).msg.vb.v == Nil);
        var prom1 := PromisePktWithHighestBallot(qrm1);
        // The highest ballot in qrm1 is not Nil
        if prom1.msg.vb.v == Nil {
            lemma_HighestPromiseValNilImpliesAllBottom(qrm1);
            assert !QuorumHasSeenB(c, ds', qrm1, b);
            assert false;
        }
        assert isPromisePkt(ds', prom1) && prom1.msg.vb.b != Bottom;

        // Establish b <= b2 < b1
        var b2 := prom1.msg.vb.b;
        var b_witness:Packet :| b_witness in qrm1 && BalLtEq(b, b_witness.msg.vb.b);    // by LargerBallotsPromiseQrms
        lemma_BalLtEqTransitivity(b, b_witness.msg.vb.b, b2);
        assert BalLtEq(b, b2);
        assert BalLt(b2, b1);       // by PromiseMsgBalLargerThanAcceptedItSees

        // Fetch Accept packet corresponding to balval seen by prom1
        var accpt2 :|   && isAcceptPkt(ds', accpt2)      // by PromiseVBImpliesAcceptMsg
                        && accpt2.msg == Accept(b2, v');
        // AgreementChosenInv_NoneChosen_AccAction_NewChosenV_LargerBallotAcceptMsgs_helper(c, ds, ds', 
        //     actor, recvIos, sendIos, b, v, accpt2, b2, v');
        axiom_BallotInduction1(c, ds', accpt, b, v);
    }
}


lemma AgreementChosenInv_NoneChosen_AccAction_NewChosenV_LargerBallotAcceptors(
c:Constants, ds:DistrSys, ds':DistrSys, actor:Id, recvIos:seq<Packet>, sendIos:seq<Packet>, b:Ballot, v:Value)
    requires Agreement_Chosen_Inv(c, ds)
    requires ds'.WF(c) && Trivialities(c, ds')
    requires Agreement_Chosen_Inv_Common(c, ds')
    requires Next(c, ds, ds')
    requires PaxosNextOneAgent(c, ds, ds', actor, recvIos, sendIos)
    requires c.ValidAccId(actor)
    requires recvIos[0].msg.Propose?
    requires AcceptorAccept(ds.acceptors[actor.idx], ds'.acceptors[actor.idx], recvIos[0], sendIos);   
    requires !SomeValueChosen(c, ds)
    requires Chosen(c, ds', b, v)
    requires LargerBallotsPromiseQrms(c, ds', b)
    requires LargerBallotAcceptMsgs(c, ds', b, v)
    ensures LargerBallotAcceptors(c, ds', b, v)
{
    forall i' | c.ValidAccIdx(i') && BalLtEq(b, ds'.acceptors[i'].accepted.b)
    ensures AcceptorHasValueV(c, ds', i', v) {
        var b', v' :=  ds'.acceptors[i'].accepted.b, ds'.acceptors[i'].accepted.v;
        if v' != v {
            var accp :| && isAcceptPkt(ds', accp)   // by AcceptedImpliesAcceptMsg
                        && accp.msg == Accept(b', v');
            assert false;   // violtes LargerBallotAcceptMsgs
        }
    }
}



lemma AgreementChosenInv_NoneChosen_AccAction_NewChosenV_LargerBallotPromiseMsgs(
c:Constants, ds:DistrSys, ds':DistrSys, actor:Id, recvIos:seq<Packet>, sendIos:seq<Packet>, b:Ballot, v:Value)
    requires Agreement_Chosen_Inv(c, ds)
    requires ds'.WF(c) && Trivialities(c, ds')
    requires Agreement_Chosen_Inv_Common(c, ds')
    requires Next(c, ds, ds')
    requires PaxosNextOneAgent(c, ds, ds', actor, recvIos, sendIos)
    requires c.ValidAccId(actor)
    requires !SomeValueChosen(c, ds)
    requires Chosen(c, ds', b, v)
    requires LargerBallotAcceptMsgs(c, ds', b, v)
    ensures LargerBallotPromiseMsgs(c, ds', b, v)
{
    forall p | isPromisePkt(ds', p) && BalLtEq(b, p.msg.vb.b)
    ensures p.msg.vb.v == v 
    {
        var b', v' := p.msg.vb.b, p.msg.vb.v;
        var ap :|  && isAcceptPkt(ds', ap)
                    && ap.src == p.src
                    && ap.msg.bal == b'
                    && ap.msg.val == v';
        assert LargerBallotAcceptMsgs(c, ds', b, v);
        if v' != v {
            assert false;
        }
    }
}


lemma AgreementChosenInv_NoneChosen_AccAction_NewChosenV_LargerBallotProposeMsgs(
c:Constants, ds:DistrSys, ds':DistrSys, actor:Id, recvIos:seq<Packet>, sendIos:seq<Packet>, b:Ballot, v:Value)
    requires Agreement_Chosen_Inv(c, ds)
    requires ds'.WF(c) && Trivialities(c, ds')
    requires Agreement_Chosen_Inv_Common(c, ds')
    requires Next(c, ds, ds')
    requires PaxosNextOneAgent(c, ds, ds', actor, recvIos, sendIos)
    requires c.ValidAccId(actor)
    requires !SomeValueChosen(c, ds)
    requires Chosen(c, ds', b, v)
    requires LargerBallotPromiseMsgs(c, ds', b, v)
    requires LargerBallotsPromiseQrms(c, ds', b)
    ensures LargerBallotProposeMsgs(c, ds', b, v)
{
    forall p | isProposePkt(ds', p) && BalLtEq(b, p.msg.bal)
    ensures p.msg.val == v
    {
        var b', v' := p.msg.bal, p.msg.val;
        if b' == b {
            assert v == v';     // by OneValuePerBallot_ProposeMsg
        } else {
            var prom_qrm :| && QuorumOfPromiseMsgs(c, ds', prom_qrm, b')
                            && (|| PromisePktWithHighestBallot(prom_qrm).msg.vb.v == v'
                                || PromisePktWithHighestBallot(prom_qrm).msg.vb.v == Nil);
            var prom := PromisePktWithHighestBallot(prom_qrm);
            var prom_smaller:Packet :| prom_smaller in prom_qrm && BalLtEq(b, prom_smaller.msg.vb.b);  // because Quorum must have seen b (LargerBallotsPromiseQrms)
            lemma_BalLtEqTransitivity(b, prom_smaller.msg.vb.b, prom.msg.vb.b);
            assert PromisePktWithHighestBallot(prom_qrm).msg.vb.v == v;     // because LargerBallotPromiseMsgs
        }
    }
}


lemma AgreementChosenInv_NoneChosen_AccAction_NewChosenV_P2LeaderV(
c:Constants, ds:DistrSys, ds':DistrSys, actor:Id, recvIos:seq<Packet>, sendIos:seq<Packet>, b:Ballot, v:Value)
    requires Agreement_Chosen_Inv(c, ds)
    requires ds'.WF(c) && Trivialities(c, ds')
    requires Agreement_Chosen_Inv_Common(c, ds')
    requires Next(c, ds, ds')
    requires PaxosNextOneAgent(c, ds, ds', actor, recvIos, sendIos)
    requires c.ValidAccId(actor)
    requires recvIos[0].msg.Propose?
    requires AcceptorAccept(ds.acceptors[actor.idx], ds'.acceptors[actor.idx], recvIos[0], sendIos);   
    requires !SomeValueChosen(c, ds)
    requires Chosen(c, ds', b, v)
    requires LargerBallotsPromiseQrms(c, ds', b)
    requires LargerBallotPromiseMsgs(c, ds', b, v)
    ensures LargerBallotPhase2LeadersV(c, ds', b, v)
{
    forall l_idx |  && c.ValidLdrIdx(l_idx) 
                    && BalLtEq(b, ds'.leaders[l_idx].ballot) 
                    && LeaderInPhase2(c, ds', l_idx) 
    ensures LeaderHasValueV(c, ds', l_idx, v)
    {
        if !LeaderHasValueV(c, ds', l_idx, v) {
            var b', v' := ds'.leaders[l_idx].ballot, ds'.leaders[l_idx].val;
            assert v' != v;
            if b' == b {
                var prop_p := lemma_ChosenImpliesProposeMsg(c, ds', b, v);
                assert v == v';
                assert false; 
            } else {
                assert BalLt(b, b');
                var qrm' :| && QuorumOfPromiseMsgs(c, ds', qrm', b')
                            && (|| PromisePktWithHighestBallot(qrm').msg.vb.v == v'
                                || PromisePktWithHighestBallot(qrm').msg.vb.v == Nil);
                if PromisePktWithHighestBallot(qrm').msg.vb.v == Nil {
                    lemma_HighestPromiseValNilImpliesAllBottom(qrm');
                    assert !QuorumHasSeenB(c, ds', qrm', b);
                    assert false;
                } else {
                    var pivot:Packet :| pivot in qrm' && BalLtEq(b, pivot.msg.vb.b);
                    assert pivot.msg.vb.v == v;
                    forall p:Packet | p in qrm' && BalLtEq(pivot.msg.vb.b, p.msg.vb.b) 
                    ensures p.msg.vb.v == v {
                        lemma_BalLtEqTransitivity(b, pivot.msg.vb.b, p.msg.vb.b);
                    }
                    lemma_PromisePktWithHighestBallotProperty(qrm', pivot, v);
                    assert PromisePktWithHighestBallot(qrm').msg.vb.v == v;
                    assert false;
                }
            }
        }
    }
}

}