"""Read-only audit of configurable FPGA simulation results and Vivado text reports."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import sys


def read_evidence(root, relative, evidence):
    path = (root / relative).resolve()
    if not path.is_relative_to(root):
        raise ValueError('Evidence path escapes project root: ' + relative)
    raw = path.read_bytes()
    evidence.append({'path': relative, 'sha256': hashlib.sha256(raw).hexdigest()})
    return raw.decode('utf-8-sig')


def timing_summary(text):
    lines = text.splitlines()
    for index, line in enumerate(lines):
        if line.strip().startswith('WNS(ns)') and 'WHS(ns)' in line:
            for row in lines[index + 1:index + 5]:
                values = row.split()
                if len(values) >= 12:
                    try:
                        nums = [float(x) for x in values[:12]]
                    except ValueError:
                        continue
                    if not all(math.isfinite(x) for x in nums):
                        break
                    return dict(zip(['wns_ns', 'tns_ns', 'setup_failing', 'setup_total',
                                     'whs_ns', 'ths_ns', 'hold_failing', 'hold_total',
                                     'wpws_ns', 'tpws_ns', 'pulse_failing', 'pulse_total'], nums))
    raise ValueError('Unsupported or incomplete timing summary table')


def utilization(text, top):
    header = None
    for line in text.splitlines():
        if not line.startswith('|'):
            continue
        fields = [x.strip() for x in line.strip('|').split('|')]
        if 'Total LUTs' in fields and 'FFs' in fields:
            header = fields
        elif header and fields[0] == top and len(fields) == len(header):
            row = dict(zip(header, fields))
            return {key: int(row[col].replace(',', '')) for key, col in
                    [('lut', 'Total LUTs'), ('ff', 'FFs'), ('ramb36', 'RAMB36'),
                     ('ramb18', 'RAMB18')]}
    raise ValueError('Top instance or supported hierarchical utilization table missing')


def audit(root, config):
    result = {'scope': 'saved_simulation_and_routed_report_evidence_only',
              'simulation_rerun': False, 'hardware_verified': False,
              'tests': [], 'implementations': [], 'evidence': [], 'warnings': []}
    for test in config['tests']:
        item = {'name': test['name'], 'path': test['path'], 'status': 'fail'}
        try:
            text = read_evidence(root, test['path'], result['evidence'])
            statuses = re.findall(r'^RESULT=([^\r\n]+)', text, re.M)
            errors = re.findall(r'\bERRORS\s*=\s*(\d+)', text, re.I)
            if statuses != ['PASS'] or not errors or any(int(x) for x in errors):
                raise ValueError('Require one RESULT=PASS and explicit zero ERRORS')
            item['status'] = 'pass'
        except (OSError, ValueError) as error:
            item['reason'] = str(error)
        result['tests'].append(item)
    for spec in config['implementations']:
        item = {'name': spec['name'], 'status': 'fail'}
        try:
            timing = read_evidence(root, spec['timing'], result['evidence'])
            util = read_evidence(root, spec['utilization'], result['evidence'])
            for text in [timing, util]:
                if not re.search(r'^\| Design State\s*:\s*Routed\s*$', text, re.M):
                    raise ValueError('Require Design State: Routed')
                if not re.search(r'^\| Design\s*:\s*' + re.escape(spec['top']) + r'\s*$', text, re.M):
                    raise ValueError('Design name does not match configured top')
            item['timing'] = timing_summary(timing)
            item['resources'] = utilization(util, spec['top'])
            clock = re.search(r'^' + re.escape(spec['clock']) +
                              r'\s+\{[^}]+\}\s+([\d.]+)\s+([\d.]+)\s*$', timing, re.M)
            if not clock:
                raise ValueError('Configured clock missing from Clock Summary')
            item['clock_period_ns'], item['clock_mhz'] = map(float, clock.groups())
            if abs(item['clock_period_ns'] - spec['period_ns']) > 0.001:
                raise ValueError('Clock period differs from configured requirement')
            t = item['timing']
            if t['wns_ns'] < 0 or t['whs_ns'] < 0 or t['wpws_ns'] < 0 or any(
                    t[k] != 0 for k in ['tns_ns', 'ths_ns', 'tpws_ns',
                                       'setup_failing', 'hold_failing', 'pulse_failing']):
                raise ValueError('Setup/hold/pulse timing requirements not met')
            for key, maximum in spec.get('max_resources', {}).items():
                if item['resources'][key] > maximum:
                    raise ValueError('Resource budget exceeded: ' + key)
            # These are disclosures, never silently interpreted as closed external timing.
            for rule, count in re.findall(r'^(TIMING-18|LUTAR-1)\s+Warning\s+.*?\s+(\d+)\s*$', timing, re.M):
                result['warnings'].append({'implementation': spec['name'], 'rule': rule, 'count': int(count)})
            external = re.search(r'^\d+\. checking no_output_delay \((\d+)\)', timing, re.M)
            if external and int(external[1]):
                result['warnings'].append({'implementation': spec['name'],
                                           'rule': 'no_output_delay', 'count': int(external[1])})
            item['status'] = 'pass'
        except (OSError, ValueError, KeyError) as error:
            item['reason'] = str(error)
        result['implementations'].append(item)
    if not result['tests'] or not result['implementations']:
        raise ValueError('Configure at least one test and one implementation')
    result['status'] = 'pass' if all(x['status'] == 'pass' for x in
                                   result['tests'] + result['implementations']) else 'fail'
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project-root', type=Path, required=True)
    parser.add_argument('--config', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    try:
        result = audit(args.project_root.resolve(), json.loads(args.config.read_text(encoding='utf-8-sig')))
    except (OSError, ValueError, KeyError, TypeError) as error:
        print('CONFIG_ERROR: ' + str(error), file=sys.stderr)
        return 2
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    print('EVIDENCE_AUDIT=' + result['status'].upper())
    print('WARNINGS=' + str(len(result['warnings'])))
    return 0 if result['status'] == 'pass' else 1


if __name__ == '__main__':
    sys.exit(main())
