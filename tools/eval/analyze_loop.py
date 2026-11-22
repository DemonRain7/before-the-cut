"""Analyze measure_loop.gd output. A full first night supplies four unprotected visitors."""
import csv
import json
import sys
from collections import Counter, defaultdict
from functools import lru_cache
from pathlib import Path

root = Path(__file__).resolve().parents[2]
rules = json.loads((root / "game/data/rules.json").read_text())
scores = rules["scoring"]
budget = rules["visit"]["lamps"]
bonus = scores["press_catch_bonus"]
names = ["eyes", "hands", "port", "temper"]
with open(sys.argv[1], newline="") as source:
    draws = list(csv.reader(source))
populations = defaultdict(Counter)
stats = Counter()
fees = set()
night_values = defaultdict(float)
blind_values = defaultdict(float)
firsts = Counter()
one_fees = defaultdict(Counter)
for line in draws:
    seed, slot, who, fee, drift, mask, leads, speech, packed, crosses, snap, flare, right, credits, fights, blind = line
    seed, slot, drift, mask, leads, speech, packed, crosses, snap, flare, right, credits, fights = map(int, (seed,slot,drift,mask,leads,speech,packed,crosses,snap,flare,right,credits,fights))
    fee = int(float(fee))
    fees.add(fee)
    night_values[seed] += credits
    order = [(packed >> shift) & 3 for shift in (6,4,2,0)]
    guided = sorted(order, key=lambda k: not (leads & 1 << k))
    def payoff(team):
        return (fee if drift else scores["false_call"]) if team else (scores["treat_drifting"] if drift else fee)
    blind_values[seed] += int(blind)
    if slot == 0:
        continue
    populations[who][(fee,drift,mask,speech)] += 1
    stats["n"] += 1
    firsts[names[guided[0]]] += 1
    n_cross = speech + sum((mask >> k) & 1 for k in order[:budget])
    c_cross = speech + sum((mask >> k) & 1 for k in guided[:budget])
    seen = sum(1 << k for k in guided[:budget])
    for key,call in (("C",c_cross >= 2),("Cbest",c_cross >= 2 or c_cross == 1 and leads & ~seen),("N0",n_cross >= 2),("N1",n_cross >= 1)):
        stats[key] += int(bool(call) == bool(drift))
    stats["one"] += c_cross == 1
    stats["onedrift"] += (c_cross == 1 and drift)
    stats["engine_right"] += right
    stats["money"] += credits
    stats["drift"] += drift
    stats["snap"] += snap
    stats["flare"] += flare
    stats["always_treat"] += payoff(False)
    stats["always_team"] += payoff(True)
    stats["always_break"] += drift * (0.9*(fee+bonus)+0.1*scores["hit"])
    if c_cross == 1:
        one_fees[fee][drift] += 1

def optimum(talk=True, tests=(0,1,2,3), lamps=budget):
    """Exact credit-optimal decision tree on the engine's empirical case/sign prior."""
    total_right = 0
    for prior in populations.values():
        for clue in (range(16) if talk else [-1]):
            for voice in ((0,1) if talk else [-1]):
                weights = []
                for (fee,drift,mask,speech),count in prior.items():
                    if talk and voice != speech:
                        continue
                    mass = float(count)
                    if talk:
                        for k in range(4):
                            prob = rules["complaints"]["broken" if mask & 1 << k else "normal"]
                            mass *= prob if clue & 1 << k else 1-prob
                    weights.append((mask,drift,fee,mass))
                @lru_cache(None)
                def tree(tested, broken):
                    obs = [r for r in weights if r[0] & tested == broken]
                    if not obs:
                        return (0.,0.)
                    happy = sum(m for _,d,_,m in obs if not d)
                    drift = sum(m for _,d,_,m in obs if d)
                    opts = [(sum(m*(scores["treat_drifting"] if d else f) for _,d,f,m in obs),happy),
                            (sum(m*(f if d else scores["false_call"]) for _,d,f,m in obs),drift)]
                    if tested.bit_count() < lamps:
                        for k in tests:
                            bit = 1 << k
                            if not tested & bit:
                                yes = tree(tested|bit, broken|bit)
                                no = tree(tested|bit, broken)
                                opts.append((yes[0]+no[0],yes[1]+no[1]))
                    return max(opts)
                total_right += tree(0,0)[1]
    return 100*total_right/stats["n"]

n = stats["n"]
pct = lambda x: round(100*x/n,3)
best = optimum()
one_d = stats["onedrift"]/stats["one"]
floor = rules["line"]["per_hour"]*rules["night"]["visitors"]
fee_table = {}
for fee in sorted(fees):
    caught = 0.9*(fee+bonus)+0.1*scores["hit"]
    fee_table[fee] = {"two_team":fee,"two_break":round(caught,2),
                      "one_treat":round((1-one_d)*fee+one_d*scores["treat_drifting"],2),
                      "one_team":round(one_d*fee+(1-one_d)*scores["false_call"],2),"one_break":round(one_d*caught,2)}
result = {"n":n,"nights":len(night_values),"C":pct(stats["C"]),"Cbest":pct(stats["Cbest"]),"N":pct(max(stats["N0"],stats["N1"])),
          "C_full_rules":pct(stats["engine_right"]), "best":round(best,3),"S":round(optimum(False),3),"T":round(optimum(lamps=0),3),
          "one":pct(stats["one"]),"one_drift":round(100*one_d,3),"fees":fee_table,
          "removed_pp":{name:round(best-optimum(tests=tuple(j for j in range(4) if j!=i)),3) for i,name in enumerate(names)},
          "first_pct":{k:pct(v) for k,v in firsts.items()},
          "credits":{k:round(stats[k]/n,2) for k in ("money","always_treat","always_team","always_break")},
          "snap_drift":round(100*stats["snap"]/stats["drift"],3),"flare":pct(stats["flare"]),
          "line_pct":[round(100*sum(v+k*rules["contacts"]["pay"]>=floor for v in night_values.values())/len(night_values),3) for k in range(3)],
          "matched_night":round(sum(night_values.values())/len(night_values)+2*rules["contacts"]["pay"],2),
          "blind_night":round(sum(blind_values.values())/len(night_values),2)}
print(json.dumps(result,indent=2))
