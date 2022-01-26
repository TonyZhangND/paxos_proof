include "types.dfy"
include "network.dfy"
include "agents.dfy"
include "synod.dfy"
include "proof_helper.dfy"
include "proof_axioms.dfy"
include "proof_agreement_invariants.dfy"

module Proof_Agreement_ChosenProperties_2 {
import opened Network
import opened Agents
import opened Types
import opened Synod
import opened Proof_Helper
import opened Proof_Axioms
import opened Proof_Agreement_Invs



/////////////////       Agreement Sub-Lemma: Some existing decision        ///////////////

lemma AgreementChosenInv_SomeChosen(c:Constants, ds:DistrSys, ds':DistrSys) 
    requires Agreement_Chosen_Inv(c, ds)
    requires ds'.WF(c) && Trivialities(c, ds')
    requires Next(c, ds, ds')
    requires Agreement_Chosen_Inv_Common(c, ds')
    requires SomeValueChosen(c, ds)
    ensures Agreement_Chosen_Inv_ChosenProperties(c, ds')
{
    var actor, recvIos:seq<Packet>, sendIos :| PaxosNextOneAgent(c, ds, ds', actor, recvIos, sendIos);
    if actor.agt == Ldr {
        // If actor is a Leader
        AgreementChosenInv_SomeChosen_LdrAction(c, ds, ds', actor, recvIos, sendIos);
    } else {
        // TODO
        assume false;
    }
}

lemma AgreementChosenInv_SomeChosen_LdrAction(
c:Constants, ds:DistrSys, ds':DistrSys, actor:Id, recvIos:seq<Packet>, sendIos:seq<Packet>)
    requires Agreement_Chosen_Inv(c, ds)
    requires ds'.WF(c) && Trivialities(c, ds')
    requires Agreement_Chosen_Inv_Common(c, ds')
    requires Next(c, ds, ds')
    requires PaxosNextOneAgent(c, ds, ds', actor, recvIos, sendIos)
    requires c.ValidLdrId(actor)
    requires SomeValueChosen(c, ds)
    ensures Agreement_Chosen_Inv_ChosenProperties(c, ds')
{
    forall b, v | Chosen(c, ds', b, v) 
    ensures Agreement_Chosen_Inv_SomeValChosen(c, ds', b, v)
    {
        lemma_NoNewAcceptsImpliesNoNewChosen(c, ds, ds');
        assert Chosen(c, ds, b, v);
        AgreementChosenInv_SomeChosen_LdrAction_LargerBallotPhase2LeadersV(c, ds, ds', actor, recvIos, sendIos, b, v);
        AgreementChosenInv_SomeChosen_LdrAction_LargerBallotAcceptors(c, ds, ds', actor, recvIos, sendIos, b, v);
        AgreementChosenInv_SomeChosen_LdrAction_LargerBallotAcceptMsgs(c, ds, ds', actor, recvIos, sendIos, b, v);       
        assert LargerBallotPhase2LeadersV(c, ds', b, v);
        assert LargerBallotAcceptors(c, ds', b, v);
        assert LargerBallotAcceptMsgs(c, ds', b, v);



        assume LargerBallotPromiseMsgs(c, ds', b, v);
        assume LargerBallotProposeMsgs(c, ds', b, v);
        assume LargerBallotsPromiseQrms(c, ds', b);


        assert SameBallotLeaderNotInPhase1(c, ds', b);
    }
}



lemma AgreementChosenInv_SomeChosen_LdrAction_LargerBallotPhase2LeadersV(
c:Constants, ds:DistrSys, ds':DistrSys, actor:Id, recvIos:seq<Packet>, sendIos:seq<Packet>, b:Ballot, v:Value)
    requires Agreement_Chosen_Inv(c, ds)
    requires ds'.WF(c) && Trivialities(c, ds')
    requires Next(c, ds, ds')
    requires PaxosNextOneAgent(c, ds, ds', actor, recvIos, sendIos)
    requires c.ValidLdrId(actor)
    requires SomeValueChosen(c, ds)
    requires Chosen(c, ds, b, v)
    requires Chosen(c, ds', b, v) 
    ensures LargerBallotPhase2LeadersV(c, ds', b, v)
{
    forall idx | 
        && c.ValidLdrIdx(idx) 
        && BalLtEq(b, ds'.leaders[idx].ballot) 
        && LeaderInPhase2(c, ds', idx) 
    ensures LeaderHasValueV(c, ds', idx, v)
    {
        if idx == actor.idx {
            var l, l' := ds.leaders[idx], ds'.leaders[idx];
            match l.state {
                case P1a => 
                    lemma_LdrP1aGoToP1(c, ds, ds', actor, recvIos, sendIos);
                    assert false;
                case P1b => 
                    AgreementChosenInv_SomeChosen_LdrAction_LargerBallotPhase2LeadersV_helper(c, ds, ds', actor, recvIos, sendIos, b, v);
                case P2a => 
                    assert l'.val == l.val;
                    assert LeaderHasValueV(c, ds', idx, v);
                case P2b => {
                    match recvIos[0].msg {
                        case Accept(bal, val) => 
                            lemma_LdrProcessAcceptDoesNotChangeValueAndBallot(c, ds, ds', actor, recvIos, sendIos);
                            assert LeaderHasValueV(c, ds', idx, v);
                        case Preempt(bal) => 
                            if BalLt(l.ballot, recvIos[0].msg.bal) {
                                assert l'.state == P1a;
                                assert false;
                            } else {
                                assert l'.val == l.val;
                                assert LeaderHasValueV(c, ds', idx, v);
                            }
                        case _ => 
                            assert l'.val == l.val;
                            assert LeaderHasValueV(c, ds', idx, v);
                    }
                }
                case Decided => 
                    assert l'.state == Decided;
                    assert false;
            }
        } else {
            assert ds'.leaders[idx] == ds.leaders[idx];
            assert LeaderInPhase2(c, ds, idx);
            assert LeaderHasValueV(c, ds', idx, v);
        }
    }
}

lemma AgreementChosenInv_SomeChosen_LdrAction_LargerBallotPhase2LeadersV_helper(
c:Constants, ds:DistrSys, ds':DistrSys, actor:Id, recvIos:seq<Packet>, sendIos:seq<Packet>, b:Ballot, v:Value)
    requires c.WF() && ds.WF(c)
    requires Trivialities(c, ds)
    
    // a la carte for faster verificaion
    requires LdrPromisesSetCorrespondToPromiseMsg(c, ds)
    requires LdrPromisesSetHaveUniqueSrc(c, ds)
    requires LdrPromisesSetHaveLeaderBallot(c, ds)
    requires LargerBallotsPromiseQrms(c, ds, b)
    requires LargerBallotPromiseMsgs(c, ds, b, v)
    requires SameBallotLeaderNotInPhase1(c, ds, b)

    requires ds'.WF(c) && Trivialities(c, ds')
    requires Next(c, ds, ds')
    requires PaxosNextOneAgent(c, ds, ds', actor, recvIos, sendIos)
    requires c.ValidLdrId(actor)
    requires SomeValueChosen(c, ds)
    requires Chosen(c, ds', b, v) 

    requires Chosen(c, ds, b, v);
    requires BalLtEq(b, ds'.leaders[actor.idx].ballot) 
    requires LeaderInPhase2(c, ds', actor.idx) 
    requires ds.leaders[actor.idx].state == P1b
    ensures LeaderHasValueV(c, ds', actor.idx, v)
{
    var l, l' := ds.leaders[actor.idx], ds'.leaders[actor.idx];
    var pkt := recvIos[0];
    match pkt.msg {
        case Promise(bal, valbal) => 
            assert l.ballot == l'.ballot;
            if pkt.msg.bal == l.ballot && !exists p :: p in l.promises && p.src == pkt.src {
                if |l.promises| == 2*l.consts.f {
                    assert l'.state == P2a;
                    var promises := l.promises + {pkt};
                    assert BalLtEq(b, l'.ballot);
                    assert PromisesSetCorrespondToPromiseMsg(c, ds, actor.idx);
                    assert isPromisePkt(ds, pkt);
                    lemma_Set_Union_Property(l.promises, promises, pkt);
                    forall p | p in promises 
                    ensures isPromisePkt(ds, p) {
                        if p == pkt {
                            assert isPromisePkt(ds, p);
                        } else {
                            assert p in l.promises;
                            assert isPromisePkt(ds, p);
                        }
                    }
                    assert QuorumOfPromiseMsgs(c, ds, promises, l.ballot);
                    if BalLt(b, l.ballot) {
                        assert QuorumHasSeenB(c, ds, promises, b);
                        lemma_QrmSeenBAndAllLargerBalsHaveSameV(c, ds, promises, l.ballot, b, v);
                    } else {
                        assert false;
                    }               
                } else {
                    assert l'.state == l.state;
                    assert false;
                }
            } else {
                assert l'.state == l.state;
                assert false;
            }
        case Preempt(bal) => 
            if BalLt(l.ballot, pkt.msg.bal) {
                assert l'.state == P1a;
                assert false;
            } else {
                assert l'.state == l.state;
                assert false;
            }
        case _ => 
            assert l'.state == l.state;
            assert false;
    }
}


lemma AgreementChosenInv_SomeChosen_LdrAction_LargerBallotAcceptors(
c:Constants, ds:DistrSys, ds':DistrSys, actor:Id, recvIos:seq<Packet>, sendIos:seq<Packet>, b:Ballot, v:Value)
    requires c.WF() && ds.WF(c)
    requires Trivialities(c, ds)
    requires ds'.WF(c) && Trivialities(c, ds')
    requires Agreement_Chosen_Inv_ChosenProperties(c, ds)
    requires Next(c, ds, ds')
    requires PaxosNextOneAgent(c, ds, ds', actor, recvIos, sendIos)
    requires c.ValidLdrId(actor)
    requires SomeValueChosen(c, ds)
    requires Chosen(c, ds, b, v) 
    requires Chosen(c, ds', b, v) 
    ensures LargerBallotAcceptors(c, ds', b, v)
{
    forall i | c.ValidAccIdx(i) 
    ensures ds'.acceptors[i] == ds.acceptors[i] {}
}


lemma AgreementChosenInv_SomeChosen_LdrAction_LargerBallotAcceptMsgs(
c:Constants, ds:DistrSys, ds':DistrSys, actor:Id, recvIos:seq<Packet>, sendIos:seq<Packet>, b:Ballot, v:Value)
    requires c.WF() && ds.WF(c)
    requires Trivialities(c, ds)
    requires ds'.WF(c) && Trivialities(c, ds')
    requires Agreement_Chosen_Inv_ChosenProperties(c, ds)
    requires Next(c, ds, ds')
    requires PaxosNextOneAgent(c, ds, ds', actor, recvIos, sendIos)
    requires c.ValidLdrId(actor)
    requires SomeValueChosen(c, ds)
    requires Chosen(c, ds, b, v) 
    requires Chosen(c, ds', b, v) 
    ensures LargerBallotAcceptMsgs(c, ds', b, v)
{}

}