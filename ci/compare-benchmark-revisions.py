import json, os, pathlib, platform, re, subprocess, sys
root=pathlib.Path.cwd(); reports=root/'reports'; reports.mkdir(exist_ok=True)
versions={'before':'b7863303929bedd8e60501d46047ab4b3e74f489','after':'56b35372b08b2192f69010ffb0e736b3de374af7'}
cpus=sorted(os.sched_getaffinity(0)); os.sched_setaffinity(0,{cpus[0]})
print(json.dumps({'pinned_cpu':cpus[0],'available_cpu_count':len(cpus),'machine':platform.machine()}),flush=True)
work={}
for name,sha in versions.items():
    path=root/f'compare-{name}'; subprocess.run(['git','worktree','add','--detach',str(path),sha],check=True);work[name]=path
rows=[]
for round in range(3):
    for name in (['before','after'] if round%2==0 else ['after','before']):
        result=subprocess.run(['zig','build','bench','-Doptimize=ReleaseFast'],cwd=work[name],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=300)
        path=reports/f'{name}-{round+1}.txt';path.write_text(result.stdout)
        if result.returncode: print(result.stdout); raise SystemExit(result.returncode)
        match=re.search(r'BENCH_JSON_BEGIN\s*(.*?)\s*BENCH_JSON_END',result.stdout,re.S);assert match,'Missing benchmark measurements'
        values=json.loads(match.group(1));gate=subprocess.run(['python3','ci/bench_gate.py','--input',str(path)],cwd=work[name],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
        (reports/f'{name}-{round+1}-gate.txt').write_text(gate.stdout)
        row={'revision':name,'sha':versions[name],'round':round+1,'gate_exit':gate.returncode,'values':values};rows.append(row);print(json.dumps(row),flush=True)
        (reports/'comparison.json').write_text(json.dumps(rows,indent=2))
# Diagnostic branch only: it can never qualify or merge the cleanup MR.
sys.exit(1 if any(x['gate_exit'] for x in rows if x['revision']=='after') else 0)
