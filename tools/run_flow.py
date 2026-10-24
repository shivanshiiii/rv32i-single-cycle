"""Portable, fail-fast regression and synthesis entry point (standard library)."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build'


def executable(name):
    value = os.environ.get(name.upper(), name)
    path = shutil.which(value)
    if not path:
        raise RuntimeError(f'{value} not found. Install it and add its executable directory to PATH.')
    return path


def run(args, log=None):
    print('+ ' + ' '.join(str(x) for x in args), flush=True)
    proc = subprocess.run(args, cwd=ROOT, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, text=True, errors='replace')
    if log:
        path = ROOT / log
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(proc.stdout, encoding='utf-8')
    if not log or proc.returncode:
        print(proc.stdout[-12000:], end='')
    else:
        for line in proc.stdout.splitlines():
            if any(token in line for token in ['PASSED', 'PASS:', 'Warning:', 'WARNING:']):
                print(line)
    if proc.returncode:
        raise RuntimeError(f'Command failed with exit code {proc.returncode}; log: {log}')
    return proc.stdout


def python(script):
    return run([sys.executable, 'tools/' + script])


def simulate(name, sources, defines=()):
    output = f'build/{name}.vvp'
    run([executable('iverilog'), '-g2012', '-Wall', '-I', 'tb', '-s', name,
         *defines, '-o', output, *sources, f'tb/{name}.v'], f'build/logs/{name}_compile.log')
    run([executable('vvp'), output], f'build/logs/{name}.log')


def versions():
    text = f'Python {sys.version.split()[0]}\n'
    for tool, flag in [('iverilog', '-V'), ('vvp', '-V'), ('yosys', '-V')]:
        try:
            result = subprocess.run([executable(tool), flag], stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, text=True, errors='replace')
            text += result.stdout.splitlines()[0] + '\n'
        except RuntimeError:
            text += tool + ': unavailable\n'
    (BUILD / 'tool_versions.txt').write_text(text, encoding='utf-8')
    print(text)


def references():
    for script in ['build_program.py', 'reference_model.py', 'build_edge_program.py',
                   'edge_reference.py']:
        python(script)


def alu_test(netlist=False):
    python('build_alu_vectors.py')
    metadata = json.loads((BUILD / 'alu_vectors.json').read_text())
    core = 'build/synth/optimized/rv32i_core_netlist.v' if netlist else 'rtl/rv32i_core.v'
    if netlist and not (ROOT / core).is_file():
        raise RuntimeError('Run synthesis before the netlist test.')
    if netlist:
        comparison = json.loads((BUILD / 'synth/comparison.json').read_text())
        actual = hashlib.sha256((ROOT / 'rtl/rv32i_core.v').read_bytes()).hexdigest()
        if comparison['optimized']['sha256'] != actual:
            raise RuntimeError('Synthesized core is stale. Run synthesis again.')
    simulate('tb_core_alu', [core], [f'-DALU_VECTOR_COUNT={metadata["instruction_vectors"]}'])
    if netlist:
        shutil.copyfile(BUILD / 'logs/tb_core_alu.log', BUILD / 'logs/netlist_alu.log')


def tests():
    references()
    core = 'rtl/rv32i_core.v'
    for bench in ['tb_soc', 'tb_soc_edge']:
        simulate(bench, [core, 'rtl/rv32i_soc.v'])
    simulate('tb_core_decode', [core])
    alu_test()
    shutil.copyfile(BUILD / 'logs/tb_core_alu.log', BUILD / 'logs/rtl_alu.log')
    print('RTL REGRESSION PASSED: four testbenches')


def synthesis():
    for label, source in [('baseline', 'baseline/rv32i_core.v'),
                          ('optimized', 'rtl/rv32i_core.v')]:
        dest = f'build/synth/{label}'
        (ROOT / dest).mkdir(parents=True, exist_ok=True)
        script = f'''read_verilog {source}
hierarchy -check -top rv32i_core
proc
opt
memory -nomap
opt
tee -o {dest}/coarse.json stat -json
synth -top rv32i_core
check -assert
select -assert-none t:$dlatch t:$_DLATCH_*
tee -o {dest}/stats.json stat -json
write_verilog -noattr {dest}/rv32i_core_netlist.v
write_json {dest}/netlist.json
'''
        path = ROOT / dest / 'run.ys'
        path.write_text(script)
        run([executable('yosys'), '-Q', '-T', '-l', f'{dest}/synthesis.log',
             '-s', f'{dest}/run.ys'], f'{dest}/console.log')
    python('summarize_synthesis.py')
    print('SYNTHESIS PASSED: baseline and optimized core')


def equivalence():
    run([executable('yosys'), '-Q', '-T', '-l', 'build/equivalence.log',
         '-s', 'synth/equivalence.ys'], 'build/equivalence.console.log')
    print('EQUIVALENCE PASSED: optimized RTL versus preserved baseline')


def manifest():
    paths = [ROOT / 'baseline/rv32i_core.v']
    for folder in ['rtl', 'tb', 'tools', 'synth']:
        paths.extend(p for p in (ROOT / folder).rglob('*')
                     if p.is_file() and '__pycache__' not in p.parts)
    result = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
              for p in sorted(paths)}
    (BUILD / 'source_sha256.json').write_text(json.dumps(result, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('target', choices=['test', 'synth', 'equiv', 'netlist', 'all', 'reference'])
    target = parser.parse_args().target
    BUILD.mkdir(exist_ok=True)
    versions()
    tasks = {'test': tests, 'synth': synthesis, 'equiv': equivalence,
             'netlist': lambda: alu_test(True), 'reference': references}
    if target == 'all':
        for task in [tests, synthesis, equivalence, lambda: alu_test(True)]:
            task()
    else:
        tasks[target]()
    manifest()
    print(f'FLOW PASSED: {target}')


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError) as exc:
        print(f'ERROR: {exc}', file=sys.stderr)
        sys.exit(1)
